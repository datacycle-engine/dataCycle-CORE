module DataCycleCore
  module Releasable

    def merge_release(data_hash, release_hash)
      data_hash = data_visitor_merge(data_hash, release_hash)
    end

    def extract_release(data_hash)
      content_hash, release_hash = data_visitor_split(data_hash)
    end


    def data_visitor_merge(data_hash, release_hash)
      release_hash.each do |key, value|
        data_hash[key] = merge_data(data_hash[key], release_hash[key])
      end
      return data_hash
    end

    def data_visitor_split(original_hash)
      data_hash = {}
      release_hash = {}
      original_hash.each do |key, value|
        data_hash[key], release_hash[key] = split_data(original_hash[key])
        release_hash[key] = nil if release_hash[key].nil? || release_hash[key].empty?
      end
      return data_hash.compact, release_hash.compact
    end


    def merge_data(data_value, release_data)
      return data_value if release_data.blank?
      if data_value.kind_of?(::Array)
        if data_value.first.kind_of?(::Hash)
          return_data = []
          data_value.each_index do |index|
            return_data.push(data_visitor_merge(data_value[index], release_data[index]))
          end
          return return_data
        end
      end
      return release_data.merge({ 'value' => data_value})
    end

    def split_data(original)
      if release_data?(original)
        return original['value'], {'release_id' => original.try(:[], 'release_id'), 'release_comment' => original.try(:[],'release_comment')}
      elsif original.kind_of?(::Hash)
        return data_visitor_split(original)
      elsif original.kind_of?(::Array)
        if original.first.kind_of?(::Hash)
          return_data = []
          return_release = []
          original.each do |item|
            data_item, release_item = data_visitor_split(item)
            return_data.push(data_item)
            return_release.push(release_item)
          end
          return return_data, return_release
        else
          return original, nil
        end 
      else
        return original, nil
      end
    end

    def release_data?(value)
      return_value = false
      return false unless value.kind_of?(::Hash)
      return true if value.has_key?('value') || value.has_key?('release_id') || value.has_key?('release_comment')
      return_value
    end

  end
end
