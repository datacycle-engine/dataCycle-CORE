module DataCycleCore
  module MasterData
    module Validators
      class Object < BasicValidator

        @@basic_types = {
            'object' => Validators::Object,
            'string' => Validators::String,
            'number' => Validators::Number,
            'geographic' => Validators::Geographic,
            'embeddedLink' => Validators::EmbeddedLink,             # only one or zero links allowed
            'embeddedLinkArray' => Validators::EmbeddedLinkArray,   # arbitray number of links to the same table allowed
            'classificationTreeLabel' => Validators::ClassificationTreeLabel
        }

        @@object_validations = ['daterange']

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

            if key_item.has_key?('validations') # validations for a particular object
              key_item['validations'].each do |val_key, val_item|
                if @@object_validations.include?(val_key)
                  self.method(val_key).call(data[key], val_item)
                else
                  @error[:warning].push "#{val_key} is not a known keyword for Object validations."
                end
              end
            end

            if key_item.has_key?('properties')
              #puts "call #{@@basic_types[key_item['type']]}.constantize.new(#{data[key]}, #{key_item['properties']},#{@schema})"
              validator_object = "#{@@basic_types[key_item['type']]}".constantize.new(data[key], key_item['properties'])
              merge_errors(validator_object.error) unless validator_object.nil?
              next
            else
              # check if it is a linked data_type
              if key_item.has_key?('name') && key_item.has_key?('description')
                # TODO: hadle embedded data_types
              else
                @error[:error].push "Object type \"#{key_item['label']}\" is not an embedded data_type, nor has it \"properties\" specified."
              end
            end

          end
          return @error
        end

      private

        def daterange(data_hash, template_hash)
          # ap data_hash
          # ap template_hash
          if template_hash.blank? || template_hash['from'].blank? || template_hash['to'].blank?
            @error[:error].push 'No fields for from-date and/or to-date specified.'
          # elsif !data_hash.has_key?(template_hash['from']) || !data_hash.has_key?(template_hash['to'])  # if we want an error when not all data are given
          #   @error[:error].push 'Fields specified in the validations are not available in the given data.'
          else
            if data_hash[template_hash['from']].blank?
              @error[:warning].push 'No data for from-date specified, assuming from-date of 1970-01-01.'
              from_date = date_time('1970-01-01')
            else
              from_date = date_time(data_hash[template_hash['from']])
            end
            if data_hash[template_hash['to']].blank?
              @error[:warning].push 'No data for to-date specified, assuming to-date of 9999-12-31.'
              to_date = date_time('9999-12-31')
            else
              to_date = date_time(data_hash[template_hash['to']])
            end
            if from_date.nil? || to_date.nil?
              @error[:error].push "Could not convert dates to validate the date-range."
            elsif from_date > to_date
              @error[:error].push "Invalid date range, from-date (#{from_date.to_date}) is after to-date (#{to_date.to_date})"
            end
          end
        end

        def date_time(data)
          begin
            data.to_datetime
          rescue
            @error[:warning].push "Failed to convert #{data} to date_time format for daterange validation."
            return nil
          end
        end

      end
    end
  end
end
