module DataCycleCore
  module MasterData
    module Validators
      class Object < BasicValidator

        @@basic_types = {
            'object' => Validators::Object,
            'string' => Validators::String,
            'number' => Validators::Number,
            'classificationTreeLabel' => Validators::ClassificationTreeLabel
        }

        def validate(data, template_data)
          data_keys = data.keys
          template_data.each_key do |key_item|
            unless data_keys.include?(template_data[key_item]['label'])
              @error[:warning].push "\"#{key_item}\" not provided in the data to evaluate."
              next
            end

            unless @@basic_types.include?(template_data[key_item]['type'])
              @error[:error].push "wrong data type for #{key_item}. Type #{template_data[key_item]['type']} not defined."
              next
            end

            unless template_data[key_item]['type'] == 'object'
              validator_object = "#{@@basic_types[template_data[key_item]['type']]}".constantize.new(data[template_data[key_item]['label']], template_data[key_item])
              merge_errors(validator_object.error) unless validator_object.nil?
              next
            end

            if template_data[key_item].has_key?('properties')
              validator_object = "#{@@basic_types[template_data[key_item]['type']]}".constantize.new(data[template_data[key_item]['label']], template_data[key_item]['properties'])
              merge_errors(validator_object.error) unless validator_object.nil?
              next
            else
              @error[:error].push "Object type \"#{template_data[key_item]['label']}\" without specified \"properties\"."
            end

          end
          return @error
        end

      end
    end
  end
end 
