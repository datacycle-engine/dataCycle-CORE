# frozen_string_literal: true

module DataCycleCore
  module Utility
    module Virtual
      module Oembed
        extend DataCycleCore::Engine.routes.url_helpers

        class << self
          def url_options
            Rails.application.config.action_mailer.default_url_options
          end

          def dc_url(content:, **_args)
            return if content.nil?

            allowed_template_names = DataCycleCore.oembed_providers['oembed_providers']
              &.pluck('output')
              &.flatten
              &.pluck('template_names')
              &.flatten || []

            return unless allowed_template_names.include?(content.template_name)

            oembed_url(thing_id: content.id)
          end

          def fetch(content:, **_args)
            return if content.id.nil?

            DataCycleCore::MasterData::Validators::Oembed.valid_oembed_from_thing_id(content.id)&.dig(:oembed)
          end
        end
      end
    end
  end
end
