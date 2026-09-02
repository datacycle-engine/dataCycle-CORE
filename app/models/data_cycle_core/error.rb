# frozen_string_literal: true

module DataCycleCore
  module Error
    # Class name plus message, skipping the message when it only repeats the class name. `to_s` and
    # not `message`, so an overridden `#message` cannot make the reporting path the thing that fails.
    def self.describe(exception)
      [exception.class.name, exception.to_s].compact_blank.uniq.join(': ')
    end

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
      class TemplateConversionError < StandardError
        attr_reader :template_name, :expected_template_name, :external_source, :external_key, :validation_errors

        def initialize(options)
          @template_name = options[:template_name]
          @expected_template_name = options[:expected_template_name]
          @external_source = options[:external_source]
          @external_key = options[:external_key]
          @validation_errors = Array.wrap(options[:validation_errors])

          super("Template conversion not feasible: #{template_name} -> #{expected_template_name} (#{@external_source&.name} -> #{@external_key}): #{@validation_errors.join('; ')}")
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

    # error of a forked child process that could not be rebuilt as its original class
    class ForkedProcessError < StandardError
    end

    module Asset
      class RemoteFileDownloadError < StandardError
      end
    end

    # Redmine #51232: merging drops the source's external system and key, and the importer's
    # ON CONFLICT is partial on live rows -- so the next run recreates the merged-away concept
    # instead of updating the target. The target can only carry one external identity, so a merge
    # that would have to pick between two is refused rather than resolved silently.
    class AmbiguousClassificationExternalSystemError < StandardError
      attr_reader :source, :target

      def initialize(source, target)
        @source = source
        @target = target

        super("cannot merge #{source.id} into #{target.id}: both carry an external system (#{source.external_source_id}/#{source.external_key} and #{target.external_source_id}/#{target.external_key}) and only one can survive")
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
        return super if wraps_itself?

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
        return super&.take(5) if wraps_itself?

        (original_error.try(:backtrace) || super)&.take(5)
      end

      private

      # defensive: `initialize` falls back to `self` when built without an original error, so both
      # readers above would delegate to themselves and recurse
      def wraps_itself?
        original_error.equal?(self)
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

    class BadRequestError < ActionController::BadRequest
      attr_reader :errors

      def initialize(errors)
        @errors = errors
        super('bad request')
      end

      def formatted_errors
        Array.wrap(errors).map do |error|
          error = transform_dry_message(error) if error.is_a?(Dry::Schema::Message)
          {
            source: { parameter: error[:path] },
            title: I18n.t("exceptions.#{self.class.name.underscore}", default: message, locale: :en),
            detail: error[:message]
          }
        end
      end

      private

      def transform_dry_message(error)
        { path: error.path, message: error.text }
      end
    end
  end
end
