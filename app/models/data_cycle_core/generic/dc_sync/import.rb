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
            options: options.merge(iteration_strategy: :import_all, mode: :incremental)
          )
        end

        def self.load_contents(mongo_item, _locale, source_filter)
          mongo_item.where(source_filter.with_evaluated_values)
        end

        def self.process_content(utility_object:, raw_data:, options:, **_unused)
          first_locale = raw_data.except('included', 'classifications', 'attribute_name', 'include_translation').keys.select { |i| i.to_sym.in?(I18n.available_locales) }&.first
          content = DataCycleCore::Thing.by_external_key(utility_object.external_source.id, raw_data[first_locale]['id']).first
          unless raw_data[first_locale]['external_source'].nil? && raw_data[first_locale]['external_key'].nil?
            content ||= DataCycleCore::Thing.by_external_key(
              DataCycleCore::ExternalSystem.find_by('identifier = ? OR name = ?', raw_data[first_locale]['external_source'], raw_data[first_locale]['external_source'])&.id,
              raw_data[first_locale]['external_key']
            ).first
          end
          if content.blank? && raw_data[first_locale]['external_system_syncs'].present?
            raw_data[first_locale]['external_system_syncs'].each do |external_system_entry|
              external_system = DataCycleCore::ExternalSystem.find_by(identifier: external_system_entry['identifier'] || external_system_entry['name'])
              next if external_system.nil?
              next if external_system_entry['external_key'].blank?
              content ||= DataCycleCore::Thing.by_external_key(external_system&.id, external_system_entry['external_key']).first
            end
          end

          if content.present? && (content&.external_source_id != utility_object.external_source.id || content&.external_key != raw_data[first_locale]['id'])
            # puts "only_snyc"
            # puts "#{raw_data[first_locale]['name']}(#{raw_data[first_locale]['id']}) --> (#{content&.external_source_id}, #{content&.external_key}) --> (#{utility_object.external_source.id}, #{raw_data[first_locale]['id']})"
            DataCycleCore::Generic::DcSync::Processing.process_only_sync(
              utility_object,
              raw_data[first_locale],
              DataCycleCore::Generic::DcSync::Processing.get_template(raw_data).template_name,
              options
            )
          else
            # puts "full import"
            # puts "#{raw_data[first_locale]['name']}(#{raw_data[first_locale]['id']}) --> (#{content&.external_source_id}, #{content&.external_key}) --> (#{utility_object.external_source.id}, #{raw_data[first_locale]['id']})"
            DataCycleCore::Generic::DcSync::Processing.process_things(
              utility_object,
              raw_data,
              DataCycleCore::Generic::DcSync::Processing.get_template(raw_data).template_name,
              options
            )
          end
        end
      end
    end
  end
end
