# frozen_string_literal: true

module DataCycleCore
  module Export
    module TextFile
      module Functions
        def self.transformations
          DataCycleCore::Export::Common::Transformations
        end

        def self.refresh(utility_object:)
          utility_object.endpoint.refresh_request
        end

        def self.update(utility_object:, data:)
          body = transformations.json_api_v2(utility_object, data)
          webhook = DataCycleCore::Export::TextFile::Webhook.new(
            data: data,
            method: 'Update',
            body: body,
            endpoint: utility_object.endpoint
          )
          webhook.perform
        end

        def self.create(utility_object:, data:)
          body = transformations.json_api_v2(utility_object, data)
          webhook = DataCycleCore::Export::TextFile::Webhook.new(
            data: data,
            method: 'Create',
            body: body,
            endpoint: utility_object.endpoint
          )
          webhook.perform
        end

        def self.delete(utility_object:, data:)
          body = transformations.json_api_v2(utility_object, data)
          webhook = DataCycleCore::Export::TextFile::Webhook.new(
            data: data,
            method: 'Delete',
            body: body,
            endpoint: utility_object.endpoint
          )
          webhook.perform
        end
      end
    end
  end
end