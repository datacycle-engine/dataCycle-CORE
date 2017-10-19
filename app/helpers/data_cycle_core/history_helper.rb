module DataCycleCore
  module HistoryHelper
    require 'hashdiff'

    def get_modified_objects(key,definition,objects,original_source)
      history_objects = transform_object_array_to_hash(objects.collect(&:get_data_hash))
      original_objects = transform_object_array_to_hash(original_source[key])
      diff_objects = get_diff(history_objects, original_objects)
      #raise diff_objects.inspect
    end

    def get_diff(version, orig)
      diff_array = HashDiff.diff(version, orig, :array_path => true, :use_lcs => true).collect {|item| transform_history_item item }
      diff_hash = transform_history_array_to_hash diff_array
    end

    def object_item_has_changed(key, definition, parent, parent_definition, object_value, modified_objects)

      # if (parent_definition.dig("type") == 'object' && (parent_definition.try(:[], 'editor').try(:[],'type') == 'objectBrowser')) ||
      #    (definition.dig("type") == 'object' && definition.dig("properties"))
      #   return false
      # end
      if (parent_definition.dig("type") == 'object' && (parent_definition.try(:[], 'editor').try(:[],'type') == 'objectBrowser'))
        return false
      end

      debug = false
      #if (key == 'text')
      if (parent.try(:get_data_hash)['id'] == 'dc8d404a-1cfa-4f38-b3bb-6d7f744edb16' && key == 'image')
        #debug = true
      end
      raise nil.inspect if debug
      unless modified_objects[parent.try(:get_data_hash)['id']].nil?
        modified_objects[parent.try(:get_data_hash)['id']].each do |object_key,object|
          if object.count == 2
            #diff with +/-
            object1 = object[0].kind_of?(Array) ? object[0][1] : object[0]
            object2 = object[1].kind_of?(Array) ? object[1][1] : object[1]
            # diff = get_diff(transform_object_array_to_hash([object1]), transform_object_array_to_hash([object2]))
            diff = get_diff(object1, object2)
            return diff[key] if diff.keys.to_a.include?(key)
          else
            #diff with ~ or only +/-
            object.each do |a, b|
              return b if a == key
              # unless b.nil?
              #   return b[key] if b.keys.to_a.include?(key)
              # end
              # return a[key] if a.keys.to_a.include?(key)
            end
            # object.each do |a, b|
            #   return b if a == key
            #   unless b.nil?
            #     return b[key] if b.keys.to_a.include?(key)
            #   end
            #   return a[key] if a.keys.to_a.include?(key)
            # end
          end
        end
      end

      return false
    end

    def item_has_changed(diff, key, value, definition)
      item_path_array = key.split('[').collect{|v| v.delete("]") }

      begin
        item_difference = diff.dig(*item_path_array)
      rescue
        return false
      end

      if item_difference.kind_of?(Array)
        return (item_difference[0][1].blank? && item_difference[0][2].blank?) ? false : item_difference
      end

      return item_difference
    end

    def transform_new_modified_objects(array, parent_id, options: {})
      if array.kind_of?(Hash)
        hash = array.each_with_object Hash.new do |(k, v), h|
          hash_key = 'id'
          if is_object?(v)
            hash_value = v[0][1].try(:[], hash_key)
          else
            hash_value = parent_id
          end
          raise "kasdf".inspect if options.dig(:test)
          unless hash_value.nil?
            h[hash_value] = {k => v}
          end
        end
        return hash unless hash.blank?
      end
      array
    end

    def is_object?(object)
      return object[0].try(:[],1).kind_of?(Hash)
    end

    private

    def transform_history_item(item)
      item_transformed = item[1].reverse.inject([item[0], item[2], item[3]]) { |hash, key|  {key => hash} }
    end

    def transform_object_array_to_hash(array, options: {})
      if array.kind_of?(Array)
        hash = array.each_with_object Hash.new do |(k, _), h|
          hash_key = 'id'
          hash_value = k[hash_key]
          raise "debug".inspect if options.dig(:test)
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
