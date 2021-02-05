# frozen_string_literal: true

module DataCycleCore
  module Generic
    module DcSync
      module Import
        def self.import_data(utility_object:, options:)
          DataCycleCore::Generic::Common::ImportFunctions.import_contents(
            utility_object: utility_object,
            iterator: method(:load_contents).to_proc,
            data_processor: method(:process_content).to_proc,
            options: options.merge(iteration_strategy: :import_all)
          )
        end

        def self.load_contents(mongo_item, _locale, source_filter)
          mongo_item.where(source_filter.with_evaluated_values)
        end

        def self.process_content(utility_object:, raw_data:, options:, **_unused)
          # check if processing is necessary
          first_locale = raw_data.except('included', 'classifications', 'attribute_name', 'include_translation').keys.select { |i| i.to_sym.in?(I18n.available_locales) }&.first
          content = DataCycleCore::Thing.by_external_key(utility_object.external_source.id, raw_data[first_locale]['id']).first
          content ||= DataCycleCore::Thing.by_external_key(DataCycleCore::ExternalSystem.find_by(identifier: raw_data[first_locale]['external_source'])&.id, raw_data[first_locale]['external_key']).first
          if content.blank? && raw_data[first_locale]['external_system_syncs'].present?
            raw_data[first_locale]['external_system_syncs'].each do |external_system_entry|
              external_system = DataCycleCore::ExternalSystem.find_by(identifier: external_system_entry['identifier'])
              content ||= DataCycleCore::Thing.by_external_key(external_system&.id, external_system_entry['external_key']).first
            end
          end

          if content.present? && (content&.external_source_id != utility_object.external_source.id || content&.external_key != raw_data[first_locale]['id'])
            DataCycleCore::Generic::DcSync::Processing.process_known_thing(
              utility_object,
              raw_data[first_locale].merge({ new: content.present? }),
              DataCycleCore::Generic::DcSync::Processing.get_template(raw_data).template_name,
              options.dig(:import, :transformations, :thing)
            )
          else
            DataCycleCore::Generic::DcSync::Processing.process_things(
              utility_object,
              raw_data.merge({ new: content.present? }),
              DataCycleCore::Generic::DcSync::Processing.get_template(raw_data).template_name,
              options.dig(:import, :transformations, :thing)
            )
          end
        end
      end
    end
  end
end
