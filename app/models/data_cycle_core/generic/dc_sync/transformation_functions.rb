# frozen_string_literal: true

module DataCycleCore
  module Generic
    module DcSync
      module TransformationFunctions
        extend Transproc::Registry
        import Transproc::HashTransformations
        import Transproc::Conditional
        import Transproc::Recursion
        import DataCycleCore::Generic::Common::Functions

        def self.transform_embedded(data, external_source_id)
          external_source = DataCycleCore::ExternalSystem.find(external_source_id)
          # thing = DataCycleCore::Thing.find_by(id: s.dig('id'))
          template = DataCycleCore::Thing.find_by(template_name: data.dig('template_name'), template: true)
          template.embedded_property_names&.each do |embedded|
            # next if data.dig(embedded).blank?
            data[embedded] = data[embedded]&.map { |item|
              handle_embedded(item, external_source)
            }&.try(:compact)
          end
          data
        end

        def self.handle_embedded(data, external_source)
          return nil if data[I18n.locale.to_s].blank?
          template = DataCycleCore::Thing.find_by(template_name: data.dig(I18n.locale.to_s, 'template_name'))
          return nil if template.blank?
          embedded = data[I18n.locale.to_s]
          # embedded['external_system_sync'] = (embedded['external_system_syncs'] || []).push('external_key' => embedded.dig('id'), 'external_source_id' => embedded.dig('external_source_id'))
          embedded['external_key'] = embedded['id']
          embedded['external_source_id'] = external_source.id
          create_thing(embedded['id'], template, external_source) if DataCycleCore::Thing.find_by(id: embedded['id']).blank?
          embedded.delete('external_system_syncs')

          embedded = embedded.merge(transform_embedded(embedded, external_source.id))
          embedded
          # make everything recursive
          # treat linked
        end

        def self.create_thing(id, template, external_source)
          content = DataCycleCore::Thing.new
          content.id = id
          content.metadata ||= {}
          content.schema = template.schema
          content.template_name = template.template_name
          content.webhook_source = external_source.name
          content.external_source_id = external_source.id
          content.external_key = id
          content.save!
        end

        def self.create_main_thing(data, external_source_id)
          if DataCycleCore::Thing.find_by(id: data.dig('id')).blank?
            create_thing(
              data.dig('id'),
              DataCycleCore::Thing.find_by(template_name: data.dig('template_name'), template: true),
              DataCycleCore::ExternalSystem.find(external_source_id)
            )
          end
          data
        end

        # def self.transform_linked_keys(data)
        #   translated_properties = data['include_translation']
        #   translated_properties&.each_key do |property_name|
        #     data[property_name] = Array.wrap(data[property_name])
        #       .map { |item| translated_properties[property_name][item] }
        #       .compact
        #   end
        #   data
        # end
      end
    end
  end
end
