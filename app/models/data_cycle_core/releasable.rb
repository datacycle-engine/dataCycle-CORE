module DataCycleCore
  module Releasable

    def merge_release(data_hash, release_hash)
      data_hash = data_iterator_merge(data_hash, release_hash)
    end

    def extract_release(data_hash, full)
      content_hash, release_hash = data_iterator_split(data_hash, full)
    end


    def data_iterator_merge(data_hash, release_hash)
      return data_hash if release_hash.blank?
      release_hash.each do |key, value|
        data_hash[key] = merge_data(data_hash[key], release_hash[key])
      end
      return data_hash
    end

    def data_iterator_split(original_hash, full)
      data_hash = {}
      release_hash = {}
      original_hash.each do |key, value|
        data_hash[key], release_hash[key] = split_data(original_hash[key], full)
        release_hash[key] = nil if release_hash[key].blank?
      end
      return data_hash.compact, release_hash.compact
    end


    def merge_data(data_value, release_data)
      return data_value if release_data.blank?
      if data_value.kind_of?(::Hash) # --> embedded data
        return data_iterator_merge(data_value, release_data)
      elsif data_value.kind_of?(::Array)
        if data_value.first.kind_of?(::Hash) # --> embeddedObjects
          return_data = []
          data_value.each_index do |index|
            return_data.push(data_iterator_merge(data_value[index], release_data[index]))
          end
          return return_data
        else
          return release_data.merge({ 'value' => data_value}) # --> Array of values
        end
      else
        return release_data.merge({ 'value' => data_value}) # --> single value
      end
    end

    def split_data(original, full)
      if release_data?(original)
        return original['value'], {'release_id' => original.try(:[], 'release_id'), 'release_comment' => original.try(:[],'release_comment')}
      elsif original.kind_of?(::Hash) # --> embedded data
        return data_iterator_split(original, full)
      elsif original.kind_of?(::Array)
        if original.first.kind_of?(::Hash) && full # --> embeddedObjects
          return_data = []
          return_release = []
          original.each do |item|
            data_item, release_item = data_iterator_split(item, full)
            return_data.push(data_item)
            return_release.push(release_item)
          end
          return return_data, return_release
        else
          return original, nil # --> Array of values
        end
      else
        return original, nil # --> single value
      end
    end

    def set_global_release(global_release_hash)
      ids = []
      flat_hash = flatten_hash(global_release_hash)
      flat_hash.map{|key,value| ids.push(value) if key[/release_id\z/]}
      max_release_status_id(ids.uniq)
    end

    def flatten_hash(data_hash, prefix=nil)
      result = {}
      data_hash = data_hash.as_json

      data_hash.map do |hash_key, hash_value|
        hash_key = "#{prefix}.#{hash_key}" if prefix.present?
        result.merge!([::Hash, ::Array].include?(hash_value.class) ? flatten_hash(hash_value,hash_key) : ({hash_key => hash_value}))
      end if data_hash.kind_of?(::Hash)

      data_hash.uniq.each_with_index do |item, index|
        index = "#{prefix}.#{index}" if prefix.present?
        result.merge!([::Hash, ::Array].include?(item.class) ? flatten_hash(item, index) : ({index => item}))
      end if data_hash.kind_of?(::Array)

      result
    end

    def release_data?(value)
      return false unless value.kind_of?(::Hash)
      return true if value.has_key?('value') || value.has_key?('release_id') || value.has_key?('release_comment')
      false
    end

  # functions to define the release logic
    def max_release_status_id(ids)
      releases = Release.order(release_code: :desc).find_by(id: ids)
      releases.nil? ? release_id_released : releases.id # nil defined as "freigegeben"
    end

    # release_code 0 defined as "freigegeben"
    def release_id_released
      Release.find_by(release_code: 0).id
    end

  # utility functions
    def release_status
      Release.find(self.release_id)
    end

    def release_status_code
      Release.find(self.release_id) ? Release.find(self.release_id).release_code : nil
    end

  end
end