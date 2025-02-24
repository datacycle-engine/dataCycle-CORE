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
              &.select(&:present?)
              &.pluck('template_names')
              &.flatten || []

            return unless allowed_template_names.include?(content.template_name)

            oembed_url(thing_id: content.id)
          end

          def fetch(content:, **args)
            return if content.id.nil?

            identifier = args&.dig(:virtual_definition, 'virtual', 'identifier') || 'id'

            thing_id = nil

            case identifier
            when 'id'
              thing_id = content.id
            when 'url'
              if content.url.present?
                url = URI.parse(content.url)
                if url.path&.include?('/things')
                  match = url.path.match(%r{things/([0-9a-fA-F-]{36})})
                  thing_id = match[1] if match
                elsif url.query&.include?('thing_id')
                  match = url.path.match(/thing_id?([0-9a-fA-F-]{36})/)
                  thing_id = match[1] if match
                else
                  oembed_remote_url = DataCycleCore::MasterData::Validators::Oembed.valid_oembed_data?(content.url)&.dig(:oembed_url)

                  if oembed_remote_url.present?
                    res = Rails.cache.fetch(oembed_remote_url, expires_in: 1.week) do
                      url = URI.parse(oembed_remote_url)
                      res = Net::HTTP.get_response(url)
                      res.is_a?(Net::HTTPSuccess) ? res.body : nil
                    end
                    return JSON.parse(res) if res.present?
                  end
                end
              end
            end

            return nil if thing_id.nil?

            DataCycleCore::MasterData::Validators::Oembed.valid_oembed_from_thing_id(thing_id)&.dig(:oembed)
          end
        end
      end
    end
  end
end
