# frozen_string_literal: true

module DataCycleCore
  module Export
    module OutdoorActive
      module Functions
        def self.transformations
          DataCycleCore::Export::Common::Transformations
        end

        def self.update(utility_object:, data:)
          external_system = utility_object.external_system
          external_system_data = data.external_system_data(external_system)
          webhook = DataCycleCore::Export::OutdoorActive::Webhook.new(
            data: data,
            external_system: external_system,
            external_system_data: external_system_data,
            endpoint: utility_object.endpoint
          )
          webhook.perform
        end

        def self.create(utility_object:, data:)
          update(utility_object: utility_object, data: data)
        end

        def self.delete(_utility_object:, _data:)
          # body = transformations.json_api_v2(utility_object, data)
          # webhook = DataCycleCore::Export::TextFile::Webhook.new(
          #   data: data,
          #   method: 'Delete',
          #   body: body,
          #   endpoint: utility_object.endpoint
          # )
          # webhook.perform
        end

        def self.outdoor_active_categories(data)
          external_source_id = DataCycleCore::ExternalSource.find_by(name: 'OutdoorActive')&.id
          data.classifications.includes(:classification_aliases)
            .map(&:classification_aliases).flatten.uniq
            &.select { |c| c.external_source_id == external_source_id }
            &.map(&:primary_classification)
        end
      end
    end
  end
end
