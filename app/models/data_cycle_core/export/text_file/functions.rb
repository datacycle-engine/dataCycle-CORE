# frozen_string_literal: true

module DataCycleCore
  module Export
    module TextFile
      module Functions
        include Transformations

        def self.transformations
          DataCycleCore::Export::TextFile::Transformations
        end

        def self.update(utility_object:, data:)
          body = transformations.json_api_v2(utility_object, data)
          webhook = DataCycleCore::Export::TextFile::Webhook.new(
            data: data,
            method: :post,
            body: body,
            endpoint: utility_object.endpoint
          )
          webhook.perform
        end
      end
    end
  end
end
