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
      end
      return data_hash.compact, release_hash.compact
    end


    def merge_data(data_value, release_data)
      return data_value if release_data.blank?
      return release_data.merge({ 'value' => data_value})
    end

    def split_data(original)
      if release_data?(original)
        return original['value'], {'release_id' => original.try(:[], 'release_id'), 'release_comment' => original.try(:[],'release_comment')}
      elsif original.kind_of?(::Hash)
        return data_visitor_split(original)
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
