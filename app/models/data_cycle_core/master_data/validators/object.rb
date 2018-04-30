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
            'datetime' => Validators::Datetime,
            'boolean' => Validators::Boolean,
            'geographic' => Validators::Geographic,
            'linked' => Validators::Linked,
            'embedded' => Validators::Embedded,
            'classification' => Validators::Classification,
            'asset' => Validators::Asset
          }
        end

        def object_validations
          ['daterange']
        end

        # validate data as specified in the keys of the data template
        # data hash with key names as specified in the schema
        def validate(data, template_data)
          return if data.blank?
          data_keys = data.keys
          template_data.each do |key, key_item|
            @template_key = key
            unless data_keys.include?(key)
              (@error[:warning][key] ||= []) << I18n.t(:no_evaluate, scope: [:validation, :warning], data: key, locale: DataCycleCore.ui_language)
              next
            end

            unless basic_types.include?(key_item['type'])
              (@error[:error][key] ||= []) << I18n.t(:object_type, scope: [:validation, :errors], data: key_item, type: key_item['type'], locale: DataCycleCore.ui_language)
              next
            end

            unless key_item['type'] == 'object'
              validator_object = basic_types[key_item['type']].new(data[key], key_item, key)
              merge_errors(validator_object.error) unless validator_object.nil?
              next
            end

            if key_item.key?('validations') # validations for a particular object
              key_item['validations'].each do |val_key, val_item|
                if object_validations.include?(val_key)
                  method(val_key).call(data[key], val_item)
                else
                  (@error[:warning][key] ||= []) << I18n.t(:keyword, scope: [:validation, :warning], key: val_key, type: 'Object', locale: DataCycleCore.ui_language)
                end
              end
            end

            if key_item.key?('properties')
              validator_object = basic_types[key_item['type']].new(data[key], key_item['properties'])
              merge_errors(validator_object.error) unless validator_object.nil?
            else
              (@error[:error][key] ||= []) << I18n.t(:wrong_object_type, scope: [:validation, :errors], data: key_item['label'], locale: DataCycleCore.ui_language)
            end
          end
          @error
        end

        private

        def verify_embedded_object(data, table, name)
          return if data.empty?
          template = ('DataCycleCore::' + table.classify).constantize
            .find_by(template: true, template_name: name)
          if template.blank?
            (@error[:error][@template_key] ||= []) << I18n.t(:no_template, scope: [:validation, :errors], name: name, locale: DataCycleCore.ui_language)
            return
          end

          data.each do |item|
            validator_object = DataCycleCore::MasterData::ValidateData.new
            merge_errors(validator_object.validate(item, template.schema))
          end
        end

        def daterange(data_hash, template_hash)
          data_hash = {} if data_hash.nil?
          if template_hash.blank? || !data_hash.key?(template_hash['from']) || !data_hash.key?(template_hash['to'])
            (@error[:error][@template_key] ||= []) << I18n.t(:no_fields, scope: [:validation, :errors], locale: DataCycleCore.ui_language)
          else
            if data_hash[template_hash['from']].blank?
              (@error[:warning][template_hash['from']] ||= []) << I18n.t(:start_date, scope: [:validation, :warning], locale: DataCycleCore.ui_language)
              from_date = date_time('1970-01-01')
            else
              from_date = date_time(data_hash[template_hash['from']])
            end
            if data_hash[template_hash['to']].blank?
              (@error[:warning][template_hash['to']] ||= []) << I18n.t(:end_date, scope: [:validation, :warning], locale: DataCycleCore.ui_language)
              to_date = date_time('9999-12-31')
            else
              to_date = date_time(data_hash[template_hash['to']])
            end
            if from_date.nil? || to_date.nil?
              (@error[:error][@template_key] ||= []) << I18n.t(:convert_date, scope: [:validation, :errors], locale: DataCycleCore.ui_language)
            elsif from_date > to_date
              (@error[:error][@template_key] ||= []) << I18n.t(:daterange, scope: [:validation, :errors], from: from_date.to_date, to: to_date.to_date, locale: DataCycleCore.ui_language)
            end
          end
        end

        def date_time(data)
          data.to_datetime
        rescue StandardError
          (@error[:warning][@template_key] ||= []) << I18n.t(:convert, scope: [:validation, :warning], data: data, locale: DataCycleCore.ui_language)
          return nil
        end
      end
    end
  end
end
