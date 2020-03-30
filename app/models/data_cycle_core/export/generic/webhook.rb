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
          @type = type
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

          if data || @type.to_s == 'delete'
            @response = @utility_object.endpoint.content_request(
              transformation: @transformation,
              method: @method,
              path: @path,
              utility_object: @utility_object,
              data: data || @data
            )
          end

          data&.add_external_system_data(@utility_object.external_system, nil, 'success')
        end

        def reference_type
          @utility_object.external_system.name.underscore_blanks
        end
      end
    end
  end
end
