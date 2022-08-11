# frozen_string_literal: true

module DataCycleCore
  module Export
    module Feratel
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
              external_key: @feratel_id,
              data: {
                message: exception.message.dup.force_encoding('UTF-8'),
                text: exception.try(:response)&.dig(:body)&.dup&.force_encoding('UTF-8')
              }
            )
        end

        def failure(_job)
          return unless @data.is_a?(DataCycleCore::Thing)

          @data.external_system_sync_by_system(external_system: @utility_object.external_system).update(status: 'failure', external_key: @feratel_id)
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

          @feratel_id = @response['Id']

          unless @data.id == @response['PartnerId']
            log("ERROR: Inconsistent Data: Thing.id sent:#{@data.id} Thing.id received:#{@response['Id']}; response:#{@response}", @data.id)
            return
          end

          return if @response['Status'] == '0' # all good

          log("ERROR: Try to update Thing.id #{@data.id}; response:#{@response}", @data.id)
        end

        def success(_job)
          return unless @data.is_a?(DataCycleCore::Thing)

          @external_system_sync = @data.external_system_sync_by_system(external_system: @utility_object.external_system)
          @external_system_sync.update(status: 'success', last_successful_sync_at: @external_system_sync.last_sync_at, external_key: @feratel_id)
        end

        def reference_type
          "#{@utility_object.external_system.identifier.underscore_blanks}_#{@type}"
        end

        def log(message, id)
          init_logging do |logger|
            logger.info(message, id)
          end
        end

        def init_logging
          logging = DataCycleCore::Generic::Logger::LogFile.new(:feratel_push_webhook)
          yield(logging)
        ensure
          logging.close if logging.respond_to?(:close)
        end
      end
    end
  end
end
