# frozen_string_literal: true

module DataCycleCore
  module Mcp
    # Translates exceptions from an MCP tool call into the same {errors: [{source:, title:,
    # detail:}]} shape as DataCycleCore::ErrorHandler (see there) -- without its controller context
    # (request/respond_to/rescue_from), which is never available during a tool call: the mcp gem
    # catches every exception out of a tool itself and generalises it into a bare
    # `-32603 Internal error` before ErrorHandler#rescue_from would ever get its turn (see
    # Tools::Publication#to_mcp_tool for the place that uses this mapping instead).
    module ErrorMapper
      module_function

      # Entry point: wraps #mapped_errors in the {errors: [...]} envelope.
      # @param locale [Symbol] language of the mount -- the text goes to the client as an error
      #   message and should be in the same language as its tool descriptions. Hard-wired to :en it
      #   was the only client-visible text that did not follow the mount's language.
      def call(exception, locale: I18n.locale)
        { errors: Array.wrap(mapped_errors(exception, locale:)) }
      end

      # Maps a known exception class to one or more {source:, title:, detail:} hashes.
      def mapped_errors(exception, locale: I18n.locale)
        case exception
        when DataCycleCore::Error::Api::BadRequestError
          Array.wrap(exception.data).map do |error|
            {
              source: { parameter: error[:parameter_path] },
              title: I18n.t("exceptions.#{exception.class.name.underscore}.#{error[:type]}", default: error[:detail] || error[:type].to_s, locale:),
              detail: error[:detail]
            }
          end
        when DataCycleCore::Error::BadRequestError
          exception.formatted_errors
        else
          [{ source: {}, title: translated(exception, locale:), detail: translated(exception, locale:) }]
        end
      end

      # The raw exception message goes out ONLY when the exception class has no translation key --
      # exactly the rule of ErrorHandler#content_api_error, whose response shape this mapping
      # mirrors.
      #
      # The message used to land in detail regardless. On a scoped find, though, the one
      # ActiveRecord phrases does not say "not found" but carries the complete WHERE condition
      # including the endpoint's template whitelist -- and for RecordNotFound
      # exceptions.active_record/record_not_found exists, where the REST API has always answered
      # with just "Not found". MCP was the only path that let the message through.
      #
      # Classes without a key (e.g. CanCan::AccessDenied) keep their message: the libraries phrase
      # those themselves and without query context. So a newly appearing exception whose message
      # gives away too much belongs in config/locales/*.yml with a key -- in one place for REST and
      # MCP together, not as a special case here.
      def translated(exception, locale: I18n.locale)
        I18n.t("exceptions.#{exception.class.name.underscore}", default: exception.message, locale:)
      end
    end
  end
end
