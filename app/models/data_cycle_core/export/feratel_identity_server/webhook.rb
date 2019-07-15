# frozen_string_literal: true

module DataCycleCore
  module Export
    module FeratelIdentityServer
      class Webhook < DataCycleCore::Export::Common::Webhook
        def initialize(data:, endpoint:, request:, external_system:, external_system_data:)
          @data = data
          @endpoint = endpoint
          @external_system = external_system
          @external_system_data = external_system_data || {}
          @request = request
        end

        def error(_job, _exception)
          data = DataCycleCore::User.find(@data.id)
          data.add_external_system_data(@external_system, nil, 'error')
        end

        def failure(_job)
          data = DataCycleCore::User.find(@data.id)
          data.add_external_system_data(@external_system, nil, 'failure')
        end

        def success(_job)
          data = DataCycleCore::User.find(@data.id)
          data.add_external_system_data(@external_system, nil, 'success')

          if @request == :create_user
            new_password = Devise.friendly_token
            data.update(provider: 'openid_connect', uid: @response['id'], skip_callbacks: true, password: new_password, password_confirmation: new_password)
          end

          external_source = DataCycleCore::ExternalSource.find_by(name: @external_system.credentials.dig('external_source'))

          return if external_source.blank?

          api_strategy = DataCycleCore.allowed_api_strategies.find { |object| object == external_source.config['api_strategy'] }
          strategy = api_strategy&.constantize&.new(external_source, nil, nil, nil)
          strategy.update Array(@response)
        end

        def perform
          data = DataCycleCore::User.find(@data.id)
          data.raw_password = @data.raw_password
          @response = @endpoint.send(@request, data: data, external_system_data: @external_system_data)
        end

        def queue_name
          "feratel_identity_server_#{@data.id}"
        end
      end
    end
  end
end
