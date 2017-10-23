module DataCycleCore
  module HistoryHelper
    require 'hashdiff'

    REMOVED_INDICATOR = '-'
    ADDED_INDICATOR = '+'
    CHANGED_INDICATOR = '~'

    # OK
    def get_diff(version, orig)
      diff_array = HashDiff.diff(version, orig, :array_path => true, :use_lcs => true).collect {|item| transform_history_item item }
      transform_history_array_to_hash diff_array
    end

    def get_object_changes(history, original)
      history_objects = transform_object_array_to_hash(history.try(:get_data_hash))
      original_objects = original.nil? ? {} : transform_object_array_to_hash(original.try(:get_data_hash))

      get_diff(history_objects, original_objects)
    end

    def find_original_object(original_object, id)
      original_object.each do |object|
        return object if object.id == id
      end
      nil
    end

    def find_history_object(original_object, id)
      original_object.each do |object|
        return object if object.try(:get_data_hash)['id'] == id
      end
      nil
    end

    def get_new_objects(history, original)
      return original if history.blank?
      history_objects = transform_object_array_to_hash(history.collect(&:get_data_hash))
      original_objects = transform_object_array_to_hash(original.collect(&:get_data_hash))
      original_objects.delete_if { |k, _| history_objects.key?(k) }.collect {|k, _| find_original_object(original,k) }
    end

    def get_removed_objects(history, original)
      return history if original.blank?
      history_objects = transform_object_array_to_hash(history.collect(&:get_data_hash))
      original_objects = transform_object_array_to_hash(original.collect(&:get_data_hash))
      history_objects.delete_if { |k, _| original_objects.key?(k) }.collect {|k, _| find_history_object(history,k) }
    end

    def get_edited_objects(history, removed)
      return history if removed.blank?
      history_objects = transform_object_array_to_hash(history.collect(&:get_data_hash))
      removed_objects = transform_object_array_to_hash(removed.collect(&:get_data_hash))
      history_objects.delete_if { |k, _| removed_objects.key?(k) }.collect {|k, _| find_history_object(history,k) }
    end

    def get_object_item_has_changed(key, definition, object_value, object_has_changed, parent_definition)

      if parent_definition.dig("type") == 'object' && (parent_definition.try(:[], 'editor').try(:[],'type') == 'objectBrowser')
        return false
      end

      get_item_has_changed(object_has_changed, key, object_value, definition)
    end

    def get_item_has_changed(diff, key, value, definition)
      item_path_array = key.split('[').collect{|v| v.delete("]") }

      begin
        diff.dig(*item_path_array)
      rescue
        return false
      end

    end

    #todo: refactor
    def getRelationObjectChanges diff
      added_objects, removed_objects = [],[]

      unless diff.blank?
        diff.each do |k,v|
          v.each do |val|
            indicator = val[0]
            value = val[1]
            case indicator
              when REMOVED_INDICATOR
                removed_objects.push(value)
              when ADDED_INDICATOR
                added_objects.push(value)
            end
          end
        end
      end

      return (added_objects-removed_objects), (removed_objects-added_objects)
    end

    private

    def transform_history_item(item)
      item_transformed = item[1].reverse.inject([item[0], item[2], item[3]]) { |hash, key|  {key => hash} }
    end

    #refactor
    def transform_object_array_to_hash(array, options: {})
      if array.kind_of?(Array)
        hash = array.each_with_object Hash.new do |(k, _), h|
          hash_key = 'id'
          hash_value = k[hash_key]
          unless hash_value.nil?
            (h[hash_value] ||= []) << k
          end
        end
        return hash unless hash.blank?
      end
      array
    end

    def transform_history_array_to_hash(array)
      array.each_with_object Hash.new do |(k, _), h|
        hash_key = k.try(:keys).try(:first)
        hash_value = k[hash_key] unless hash_key.nil?
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
