# frozen_string_literal: true

module DataCycleCore
  module Export
    module TextFile
      module Functions
        def self.transformations
          DataCycleCore::Export::Common::Transformations
        end

        def self.refresh(utility_object:, options:)
          utility_object.endpoint.refresh_request(options)
        end

        def self.update(utility_object:, data:)
          body = transformations.json_api_v2(utility_object, data)
          webhook = DataCycleCore::Export::TextFile::Webhook.new(
            data:,
            method: 'Update',
            body:,
            endpoint: utility_object.endpoint
          )
          webhook.perform
        end

        def self.create(utility_object:, data:)
          body = transformations.json_api_v2(utility_object, data)
          webhook = DataCycleCore::Export::TextFile::Webhook.new(
            data:,
            method: 'Create',
            body:,
            endpoint: utility_object.endpoint
          )
          webhook.perform
        end

        def self.delete(utility_object:, data:)
          body = transformations.json_api_v2(utility_object, data)
          webhook = DataCycleCore::Export::TextFile::Webhook.new(
            data:,
            method: 'Delete',
            body:,
            endpoint: utility_object.endpoint
          )
          webhook.perform
        end
      end
    end
  end
end
