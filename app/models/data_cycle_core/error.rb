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

      class UserApiRankError < StandardError
      end
    end

    module Download
      class InvalidSerializationFormatError < StandardError
      end

      class SerializationError < StandardError
      end

      class RepeatedFailureError < StandardError
      end
    end

    module Import
      class TemplateMismatchError < StandardError
        attr_reader :template_name, :expected_template_name, :external_source, :external_key

        def initialize(options)
          @template_name = options[:template_name]
          @expected_template_name = options[:expected_template_name]
          @external_source = options[:external_source]
          @external_key = options[:external_key]

          super("Template mismatch: #{template_name} != #{expected_template_name} (#{@external_source&.name} -> #{@external_key})")
        end
      end

      class RepeatedFailureError < StandardError
      end
    end

    module Report
      class ProcessingError < StandardError
      end
    end

    class RecordNotFoundError < StandardError
    end

    module Asset
      class RemoteFileDownloadError < StandardError
      end
    end

    class DeprecatedMethodError < StandardError
    end

    class GeojsonError < StandardError
    end

    class WebhookError < StandardError
      attr_reader :original_error

      def initialize(original_error)
        @original_error = original_error || self
        super
      end

      def message
        message = [original_error.message]

        if original_error.try(:response).present?
          if original_error.response.key?(:request)
            message.push('===================================================================')
            message.push("request_method: #{original_error.response.dig(:request, :method)}") if original_error.response[:request].key?(:method)
            message.push("request_url_path: #{original_error.response.dig(:request, :url_path)}") if original_error.response[:request].key?(:url_path)
            message.push("request_body: #{original_error.response.dig(:request, :body)}") if original_error.response[:request].key?(:body)
          end

          message.push('===================================================================')
          message.push("response_status: #{original_error.response[:status]}") if original_error.response.key?(:status)

          if original_error.response.key?(:body)
            data_string = original_error.response[:body].to_s.split("\n")
            data_string_size = data_string.size
            data_string = data_string.first(20)
            data_string += ["... MORE: + #{data_string_size - 20} lines\n"] if data_string_size > 20
            message.push("response_body: #{data_string.join("\n")}")
          end
        end

        message.map { |s| s.to_s.encode('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '').delete("\u0000") }.join("\n")
      end

      def backtrace
        (original_error.try(:backtrace) || super)&.take(5)
      end
    end

    class ApiCacheReadError < StandardError
      attr_reader :cache_key, :graph

      def initialize(options)
        @cache_key = options[:cache_key]
        @graph = options[:cache_content]

        super
      end

      def message
        DataCycleCore::NormalizeService.normalize_encoding([
          "exception: #{self.class.name}",
          "cache_key: #{cache_key}",
          "cache_content: #{graph.to_json}"
        ].join("\n"))
      end

      def backtrace
        super&.take(5)
      end
    end

    module Filter
      class DateFilterRangeError < StandardError
        attr_reader :start_date, :end_date

        def initialize(dates = [])
          @start_date = dates[0]
          @end_date = dates[1]

          super
        end

        def message
          'end date must be equal or greater then start date in date filters'
        end
      end

      class FilterRecursionError < StandardError
        def message
          'stored filters cannot filter on themselves (infinite recursion)'
        end
      end
    end

    class TemplateNotAllowedError < StandardError
      attr_reader :template_name, :expected_template_names

      def initialize(template_name, expected_template_names)
        @template_name = template_name
        @expected_template_names = Array.wrap(expected_template_names).join(', ')

        if @template_name.blank?
          super("Template missing! (allowed: #{@expected_template_names})")
        else
          super("Template not allowed: #{@template_name}, (allowed: #{@expected_template_names})")
        end
      end
    end

    class NoValidClassificationAttributeError < StandardError
    end
  end
end
