# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Common
      module DeleteContentsUpdateAttributes
        def self.import_data(utility_object:, options:)
          DataCycleCore::Generic::Common::ImportFunctions.import_contents(
            utility_object: utility_object.tap { |obj| obj.mode = :full },
            iterator: method(:load_contents).to_proc,
            data_processor: method(:process_content).to_proc,
            options:
          )
        end

        def self.load_contents(filter_object:)
          filter_object.except(:without_deleted, :without_archived).with_deleted.query
        end

        def self.process_content(utility_object:, raw_data:, locale:, options:)
          last_success = utility_object.external_source.last_successful_try(utility_object.download_object.step_name)
          raise 'Update Attributes canceled (No successful download detected)!' if last_success.blank?

          last_download = utility_object.external_source.last_try
          raise "Update Attributes canceled (Last download(s) failed)! Last success: #{last_success}, last try: #{last_download}" if last_download.present? && last_success < last_download

          delete_deadline = eval(options.dig(:import, :last_successful_try)) if options.dig(:import, :last_successful_try).present? # rubocop:disable Security/Eval
          if delete_deadline.present? && last_success < delete_deadline
            last_date = last_success.presence || 'never'
            delete_date = delete_deadline.presence || 'not specified'
            raise "No recent successful download detected! Last successful Download: #{last_date}, delete deadline: #{delete_date}"
          end

          I18n.with_locale(locale) do
            external_key_path = options.dig(:import, :external_key_path).split('.')

            raise "No external id found! Item: #{raw_data['Id']}, external_key_path: #{external_key_path}" if raw_data.dig(*external_key_path).blank?

            update_item = DataCycleCore::Thing.find_by(
              external_source_id: utility_object.external_source.id,
              external_key: options.dig(:import, :external_key_prefix).present? ? options.dig(:import, :external_key_prefix) + raw_data.dig(*external_key_path).to_s : raw_data.dig(*external_key_path).to_s
            )

            return if update_item.blank?

            attributes = validate_attributes(update_item, options.dig(:import, :attributes))
            update_hash = {}
            attributes.each do |attribute|
              next unless update_item.respond_to?(attribute[:key]&.to_s)
              value = load_value_for_attribute(attribute, utility_object)
              if attribute[:key] == 'universal_classifications' || attribute[:type] == 'classification'
                delete = attribute[:delete] || false
                update = false
                old_value = if attribute[:key] == 'universal_classifications'
                              update_item.universal_classifications.pluck(:id)
                            else
                              update_item.send(attribute[:key]).pluck(:id)
                            end

                if delete && old_value.include?(*value)
                  new_value = old_value - value
                  update = true
                elsif !delete && old_value.exclude?(*value)
                  new_value = old_value + value
                  update = true
                end
                update_hash[attribute[:key]] = new_value if update
              elsif value.present?
                update_hash[attribute[:key]] = value
              elsif value.nil? && attribute[:value].nil?
                # here we want to delete the attribute
                update_hash[attribute[:key]] = nil
              end
            end

            update_item.set_data_hash(prevent_history: false, data_hash: update_hash) if update_hash.present?
          end
        end

        def self.load_value_for_attribute(attribute, utility_object)
          case attribute[:type]
          when 'classification'
            utility_object.concept_by_path(attribute[:value])&.pluck(:classification_id)
          when 'float'
            attribute[:value].to_f
          when 'integer'
            attribute[:value].to_i
          when 'string'
            attribute[:value].to_s
          end
        end

        def self.validate_attributes(thing, attributes)
          attributes = attributes.map { |attribute|
            type = thing.properties_for(attribute[:key])&.dig('type')
            if type.blank?
              nil
            else
              attribute[:type] = type
              attribute
            end
          }.compact_blank
          raise 'The value key must be defined for all attributes (set it to null (~) to delete)' if attributes.any? { |attribute| !attribute.key?(:value) }

          raise 'The combination of key and value must be unique' if attributes.map { |attribute| attribute.slice(:key, :value) }.uniq.length != attributes.length
          attributes
        end
      end
    end
  end
end
