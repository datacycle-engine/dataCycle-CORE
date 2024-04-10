# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Validators
      class Object < BasicValidator
        def basic_types
          {
            'object' => Validators::Object,
            'key' => Validators::Key,
            'string' => Validators::String,
            'number' => Validators::Number,
            'date' => Validators::Date,
            'datetime' => Validators::Datetime,
            'boolean' => Validators::Boolean,
            'geographic' => Validators::Geographic,
            'linked' => Validators::Linked,
            'embedded' => Validators::Embedded,
            'classification' => Validators::Classification,
            'asset' => Validators::Asset,
            'schedule' => Validators::Schedule,
            'opening_time' => Validators::Schedule,
            'collection' => Validators::Collection
          }
        end

        def object_validations
          ['daterange']
        end

        # validate data as specified in the keys of the data template
        # data hash with key names as specified in the schema
        def validate(data, template_data, strict = false)
          return if data.blank?
          data_keys = data.keys
          template_data.each do |key, key_item|
            @template_key = key

            next if !strict && data_keys.exclude?(key)

            next if key_item['type'].in?(['slug', 'timeseries'])

            unless basic_types.include?(key_item['type'])
              (@error[:error][key] ||= []) << {
                path: 'validation.errors.object_type',
                substitutions: {
                  data: key_item,
                  type: key_item['type']
                }
              }

              next
            end

            unless key_item['type'] == 'object'
              validator_object = basic_types[key_item['type']].new(data[key], key_item, key, strict, @content)
              merge_errors(validator_object.error) unless validator_object.nil?
              next
            end

            if key_item.key?('validations') # validations for a particular object
              key_item['validations'].each do |val_key, val_item|
                next unless object_validations.include?(val_key)

                method(val_key).call(data[key], val_item)
              end
            end

            if key_item.key?('properties')
              validator_object = basic_types[key_item['type']].new(data[key], key_item['properties'], '', strict)
              merge_errors(validator_object.error) unless validator_object.nil?
            else
              (@error[:error][key] ||= []) << {
                path: 'validation.errors.wrong_object_type',
                substitutions: {
                  data: key_item['label']
                }
              }
            end
          end

          @error
        end

        private

        def daterange(data_hash, template_hash)
          data_hash = {} if data_hash.nil?
          if template_hash.blank? || template_hash['from'].blank? || template_hash['to'].blank?
            (@error[:error][@template_key] ||= []) << { path: 'validation.errors.no_fields' }
          else
            if data_hash[template_hash['from']].blank?
              from_date = date_time('1970-01-01')
            else
              from_date = date_time(data_hash[template_hash['from']])
            end
            if data_hash[template_hash['to']].blank?
              to_date = date_time('9999-12-31')
            else
              to_date = date_time(data_hash[template_hash['to']])
            end
            if from_date.nil? || to_date.nil?
              (@error[:error][@template_key] ||= []) << { path: 'validation.errors.convert_date' }
            elsif from_date > to_date
              (@error[:error][@template_key] ||= []) << {
                path: 'validation.errors.daterange',
                substitutions: {
                  from: from_date.to_date,
                  to: to_date.to_date
                }
              }
            end
          end
        end

        def date_time(data)
          data.to_datetime
        rescue StandardError
          nil
        end
      end
    end
  end
end
