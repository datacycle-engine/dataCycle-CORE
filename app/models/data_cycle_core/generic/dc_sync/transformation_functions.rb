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

        def self.create_main_thing(data, external_source_id)
          if data[:new] && DataCycleCore::Thing.find_by(id: data.dig('id')).blank?
            create_thing(
              data.dig('id'),
              DataCycleCore::Thing.find_by(template_name: data.dig('template_name'), template: true),
              DataCycleCore::ExternalSystem.find(external_source_id)
            )
          end
          data
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
      end
    end
  end
end
