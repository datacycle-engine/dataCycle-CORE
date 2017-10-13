module DataCycleCore
  module HistoryHelper
    require 'hashdiff'

    def get_diff(version, orig)
      diff_array = HashDiff.diff(version, orig, :array_path => true).collect {|item| transform_history_item item }
      diff_hash = transform_history_array_to_hash diff_array
    end

    def item_hash_changed(diff, key, value, definition)
      item_path_array = key.split('[').collect{|v| v.delete("]") }

      if definition.dig("type") == 'object' && definition.dig("properties")
        return nil
      else
        begin
          item_difference = diff.dig(*item_path_array)
        rescue
          return nil
        end
      end

      if item_difference.kind_of?(Array)
        return (item_difference[0][1].blank? && item_difference[0][2].blank?) ? nil : item_difference
      end

      return item_difference
    end

    private

    def transform_history_item(item)
      item_transformed = item[1].reverse.inject([item[0], item[2], item[3]]) { |hash, key|  {key => hash} }
    end

    def transform_history_array_to_hash(array)

      array.each_with_object Hash.new do |(k, _), h|
        hash_key = k.keys.first
        hash_value = k[hash_key]
        if hash_value.kind_of?(Hash)
          h[hash_key] ||= Hash.new
          (h[hash_key][hash_value.keys.first] ||= []) << hash_value[hash_value.keys.first]
        else
          (h[hash_key] ||= []) << hash_value
        end
      end

    end

  end
end
