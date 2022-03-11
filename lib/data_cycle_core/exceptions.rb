# frozen_string_literal: true

module DataCycleCore
  module Error
    module Api
      class InvalidArgumentError < StandardError
      end

      class TimeOutError < StandardError
      end

      class BadRequestError < StandardError
        attr_reader :data

        def initialize(data)
          @data = data
          super
        end
      end

      class ExpiredContentError < BadRequestError
      end
    end

    module Download
      class InvalidSerializationFormatError < StandardError
      end
    end

    module Report
      class ProcessingError < StandardError
      end
    end

    class RecordNotFoundError < StandardError
    end

    class DeprecatedMethodError < StandardError
    end

    class WebhookError < StandardError
      attr_reader :original_error

      def initialize(original_error)
        @original_error = original_error || self
        super
      end

      def message
        message = [original_error.message]

        return message.join("\n").delete("\u0000").encode('UTF-8', invalid: :replace, undef: :replace, replace: '') if original_error.try(:response).nil?

        if original_error.response.key?(:request)
          message.push('===================================================================')
          message.push("request_method: #{original_error.response.dig(:request, :method)}") if original_error.response[:request].key?(:method)
          message.push("request_url_path: #{original_error.response.dig(:request, :url_path)}") if original_error.response[:request].key?(:url_path)
          message.push("request_body: #{original_error.response.dig(:request, :body)}") if original_error.response[:request].key?(:body)
        end

        message.push('===================================================================')
        message.push("response_status: #{original_error.response[:status]}") if original_error.response.key?(:status)
        message.push("response_body: #{original_error.response[:body]}") if original_error.response.key?(:body)

        message.join("\n").delete("\u0000").encode('UTF-8', invalid: :replace, undef: :replace, replace: '')
      end

      def backtrace
        (original_error.try(:backtrace) || super)&.take(5)
      end
    end
  end
end
