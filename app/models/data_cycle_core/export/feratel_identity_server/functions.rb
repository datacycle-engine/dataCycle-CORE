# frozen_string_literal: true

module DataCycleCore
  module Export
    module FeratelIdentityServer
      module Functions
        def self.update(utility_object:, data:)
          external_system = utility_object.external_system
          external_system_data = data.external_system_data(external_system)
          data.add_external_system_data(external_system, nil, 'pending')

          Delayed::Job.enqueue(
            DataCycleCore::Export::FeratelIdentityServer::Webhook.new(
              data: OpenStruct.new(id: data.id, template_name: data.class.name),
              external_system: external_system,
              external_system_data: external_system_data,
              endpoint: utility_object.endpoint,
              request: :update_user
            )
          )
        end

        def self.create(utility_object:, data:)
          external_system = utility_object.external_system
          external_system_data = data.external_system_data(external_system)
          data.add_external_system_data(external_system, nil, 'pending')

          Delayed::Job.enqueue(
            DataCycleCore::Export::FeratelIdentityServer::Webhook.new(
              data: OpenStruct.new(id: data.id, template_name: data.class.name, raw_password: data.raw_password),
              external_system: external_system,
              external_system_data: external_system_data,
              endpoint: utility_object.endpoint,
              request: :create_user
            )
          )
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
      end
    end
  end
end
