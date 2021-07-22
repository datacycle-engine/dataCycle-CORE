# frozen_string_literal: true

module DataCycleCore
  module Export
    module Generic
      class Webhook < DataCycleCore::Export::Common::Webhook
        def initialize(data:, method:, transformation:, path:, utility_object:, type:, locale:)
          @data = data
          @method = method
          @transformation = transformation
          @utility_object = utility_object
          @path = path
          @type = type.to_s
          @locale = locale || I18n.locale
        end

        def error(_job, exception)
          return unless @data.is_a?(DataCycleCore::Thing)

          @data
            .external_system_sync_by_system(external_system: @utility_object.external_system)
            .update(
              status: 'error',
              data: {
                message: exception.message.dup.force_encoding('UTF-8'),
                text: exception.try(:response)&.dig(:body)&.dup&.force_encoding('UTF-8')
              }
            )
        end

        def failure(_job)
          return unless @data.is_a?(DataCycleCore::Thing)

          @data.external_system_sync_by_system(external_system: @utility_object.external_system).update(status: 'failure')
        end

        def before(_job)
          data = @data
          @data = DataCycleCore::Thing.find_by(id: @data.id) || @data

          return unless @data.is_a?(DataCycleCore::Thing)

          @data.webhook_data = data.webhook_data
          @data.original_id = data.original_id
          @data.external_system_sync_by_system(external_system: @utility_object.external_system).update(last_sync_at: Time.zone.now)
        end

        def perform
          I18n.with_locale(@data.try(:first_available_locale, @locale)) do
            @response = @utility_object.endpoint.content_request(
              transformation: @transformation,
              method: @method,
              path: @path,
              utility_object: @utility_object,
              data: @data
            )
          end
        end

        def success(_job)
          return unless @data.is_a?(DataCycleCore::Thing)

          @external_system_sync = @data.external_system_sync_by_system(external_system: @utility_object.external_system)
          @external_system_sync.update(status: 'success', last_successful_sync_at: @external_system_sync.last_sync_at)
        end

        def reference_type
          "#{@utility_object.external_system.identifier.underscore_blanks}_#{@type}"
        end
      end
    end
  end
end
