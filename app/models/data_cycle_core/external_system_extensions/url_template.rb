# frozen_string_literal: true

module DataCycleCore
  module ExternalSystemExtensions
    # `external_url` / `external_detail_url` are free-form format strings from the external
    # system config, so a typo raises where the URL is rendered: an unknown placeholder gives
    # KeyError, a percent-encoded character (`%20`) TypeError, a stray format flag ArgumentError.
    # Those URLs are rendered into the APIv4 `identifier` payload, where a single misconfigured
    # system would otherwise break the whole (list) response - so treat a broken template like a
    # missing one and log it instead.
    module UrlTemplate
      private

      def format_url_template(template, **)
        return if template.blank?

        format(template, **)
      rescue KeyError, ArgumentError, TypeError => e
        Rails.logger.error("[external_system_url_template] #{e.class}: #{e.message} (template: #{template.inspect})")
        nil
      end
    end
  end
end
