# frozen_string_literal: true

module DataCycleCore
  module Export
    module MediaArchive
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
          data = DataCycleCore::Thing.find_by(id: @data.id)
          data&.add_external_system_data(@utility_object.external_system, { message: exception.message, text: exception.try(:response)&.dig(:body) }, 'error')
        end

        def failure(_job)
          data = DataCycleCore::Thing.find_by(id: @data.id)
          data&.add_external_system_data(@utility_object.external_system, nil, 'failure')
        end

        def perform
          data = DataCycleCore::Thing.find_by(id: @data.id)
          system_sync = data.try(:external_system_sync_by_system, @utility_object.external_system)
          system_sync&.update(last_sync_at: Time.zone.now)

          if data || @type == 'delete'
            @response = @utility_object.endpoint.content_request(
              transformation: @transformation,
              method: @method,
              path: @path,
              utility_object: @utility_object,
              data: data || @data
            )
          end

          data&.add_external_system_data(@utility_object.external_system, nil, 'success')
          system_sync&.update(last_successful_sync_at: system_sync.last_sync_at)

          begin
            json_body = JSON.parse(@response.body)

            system_sync&.update(data: (system_sync&.data || {}).merge('external_key' => json_body['id'])) if json_body&.dig('id').present?
          rescue JSON::ParserError
            nil
          end

          data.try(:author)&.each do |author|
            author&.add_external_system_data(@utility_object.external_system, nil, 'success')
          end

          data.try(:copyright_holder)&.each do |copyright_holder|
            copyright_holder&.add_external_system_data(@utility_object.external_system, nil, 'success')
          end
        end

        def reference_type
          "#{@utility_object.external_system.name.underscore_blanks}_#{@type}"
        end
      end
    end
  end
end
