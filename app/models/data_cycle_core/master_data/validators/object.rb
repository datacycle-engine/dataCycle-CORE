module DataCycleCore
  module MasterData
    module Validators
      class Object < BasicValidator

        @@basic_types = {
            'object' => Validators::Object,
            'string' => Validators::String,
            'number' => Validators::Number,
            'embeddedLink' => Validators::EmbeddedLink,             # only one or zero links allowed
            'embeddedLinkArray' => Validators::EmbeddedLinkArray,   # arbitray number of links to the same table allowed
            'classificationTreeLabel' => Validators::ClassificationTreeLabel
        }

        # validate data as specified in the keys of the data template
        # data hash with key names as specified in the schema
        def validate(data, template_data)
          data_keys = data.keys
          template_data.each do |key, key_item|
            unless data_keys.include?(key)
              @error[:warning].push "\"#{key}\" not provided in the data to evaluate."
              next
            end

            unless @@basic_types.include?(key_item['type'])
              @error[:error].push "wrong data type for #{key_item}. Type #{key_item['type']} not defined."
              next
            end

            unless key_item['type'] == 'object'
              #puts "call #{@@basic_types[key_item['type']]}.constantize.new(#{data[key]}, #{key_item})"
              validator_object = "#{@@basic_types[key_item['type']]}".constantize.new(data[key], key_item)
              merge_errors(validator_object.error) unless validator_object.nil?
              next
            end

            if key_item.has_key?('properties')
              #puts "call #{@@basic_types[key_item['type']]}.constantize.new(#{data[key]}, #{key_item['properties']},#{@schema})"
              validator_object = "#{@@basic_types[key_item['type']]}".constantize.new(data[key], key_item['properties'])
              merge_errors(validator_object.error) unless validator_object.nil?
              next
            else
              @error[:error].push "Object type \"#{key_item['label']}\" without specified \"properties\"."
            end

          end
          return @error
        end


      end
    end
  end
end
