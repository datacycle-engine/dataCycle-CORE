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
          'classificationTreeLabel' => Validators::ClassificationTreeLabel,
          'asset' => Validators::Asset
        }

        @@object_validations = ['daterange']

        # validate data as specified in the keys of the data template
        # data hash with key names as specified in the schema
        def validate(data, template_data)
          return if data.blank?
          data_keys = data.keys
          template_data.each do |key, key_item|
            unless data_keys.include?(key)
              @error[:warning].push I18n.t :no_evaluate, scope: [:validation, :warning], data: key, locale: DataCycleCore.ui_language
              next
            end

            unless @@basic_types.include?(key_item['type'])
              @error[:error].push I18n.t :object_type, scope: [:validation, :errors], data: key_item, type: key_item['type'], locale: DataCycleCore.ui_language
              next
            end

            unless key_item['type'] == 'object'
              # puts "call #{@@basic_types[key_item['type']]}.constantize.new(#{data[key]}, #{key_item})"
              validator_object = (@@basic_types[key_item['type']]).to_s.constantize.new(data[key], key_item)
              merge_errors(validator_object.error) unless validator_object.nil?
              next
            end

            if key_item.key?('validations') # validations for a particular object
              key_item['validations'].each do |val_key, val_item|
                if @@object_validations.include?(val_key)
                  method(val_key).call(data[key], val_item)
                else
                  @error[:warning].push I18n.t :keyword, scope: [:validation, :warning], key: val_key, type: 'Object', locale: DataCycleCore.ui_language
                end
              end
            end

            if key_item.key?('properties')
              # puts "call #{@@basic_types[key_item['type']]}.constantize.new(#{data[key]}, #{key_item['properties']},#{@schema})"
              validator_object = (@@basic_types[key_item['type']]).to_s.constantize.new(data[key], key_item['properties'])
              merge_errors(validator_object.error) unless validator_object.nil?
              next
            elsif key_item.key?('name') && key_item.key?('storage_location')
              # check if it is a linked data_type
              verify_embedded_object(data[key], key_item['storage_location'], key_item['name'])
            else
              @error[:error].push I18n.t :wrong_object_type, scope: [:validation, :errors], data: key_item['label'], locale: DataCycleCore.ui_language
            end
          end
          @error
        end

        private

        def verify_embedded_object(data, table, name)
          return if data.empty?
          template = ('DataCycleCore::' + table.classify).constantize
            .with_translations('de')
            .find_by(template: true, template_name: name)

          if template.blank?
            @error[:error].push I18n.t :no_template, scope: [:validation, :errors], name: name, locale: DataCycleCore.ui_language
            return
          end

          data.each do |item|
            validator_object = DataCycleCore::MasterData::ValidateData.new
            merge_errors(validator_object.validate(item, template.schema))
          end
        end

        def daterange(data_hash, template_hash)
          data_hash = {} if data_hash.nil?
          # ap data_hash
          # ap template_hash
          if template_hash.blank? || template_hash['from'].blank? || template_hash['to'].blank?
            @error[:error].push I18n.t :no_fields, scope: [:validation, :errors], locale: DataCycleCore.ui_language
            # elsif !data_hash.has_key?(template_hash['from']) || !data_hash.has_key?(template_hash['to'])  # if we want an error when not all data are given
            #   @error[:error].push 'Fields specified in the validations are not available in the given data.'
          else
            if data_hash[template_hash['from']].blank?
              @error[:warning].push I18n.t :start_date, scope: [:validation, :warning], locale: DataCycleCore.ui_language
              from_date = date_time('1970-01-01')
            else
              from_date = date_time(data_hash[template_hash['from']])
            end
            if data_hash[template_hash['to']].blank?
              @error[:warning].push I18n.t :end_date, scope: [:validation, :warning], locale: DataCycleCore.ui_language
              to_date = date_time('9999-12-31')
            else
              to_date = date_time(data_hash[template_hash['to']])
            end
            if from_date.nil? || to_date.nil?
              @error[:error].push I18n.t :convert_date, scope: [:validation, :errors], locale: DataCycleCore.ui_language
            elsif from_date > to_date
              @error[:error].push I18n.t :daterange, scope: [:validation, :errors], from: from_date.to_date, to: to_date.to_date, locale: DataCycleCore.ui_language
            end
          end
        end

        def date_time(data)
          data.to_datetime
        rescue StandardError
          @error[:warning].push I18n.t :convert, scope: [:validation, :warning], data: data, locale: DataCycleCore.ui_language
          return nil
        end
      end
    end
  end
end
