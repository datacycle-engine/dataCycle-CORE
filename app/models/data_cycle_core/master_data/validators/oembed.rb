# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Validators
      class Oembed < BasicValidator
        def initialize(data, template, template_key = '', strict = false, content = nil)
          @content = content
          @error = { error: {}, warning: {}, result: {} }
          @template_key = template_key || 'oembed'
          validate(data, template, strict)
        end

        def oembed_keywords
          ['required', 'soft_required']
        end

        def validate(data, template, _strict = false)
          uri = Addressable::URI.parse(data)
          valid_url = uri.respond_to?(:scheme) && uri.respond_to?(:host) && uri&.scheme.present? && uri&.host.present? && ['https', 'http'].include?(uri.scheme) && uri.host.present?

          if valid_url
            data_valid = DataCycleCore::MasterData::Validators::Oembed.valid_oembed_data?(data)
            if data_valid.dig(:success) == true
              if template.key?('validations')
                template['validations'].each_key do |key|
                  method(key).call(data, template['validations'][key]) if oembed_keywords.include?(key)
                end
              end
              (@error[:result][@template_key] ||= []) << data_valid[:oembed_url]
            else
              (@error[:error][@template_key] ||= []).concat(data_valid[:error]&.dig(:error)&.values&.flatten || [])
            end

          else
            (@error[:error][@template_key] ||= []) << {
              path: 'validation.errors.oembed_unsupported_url',
              substitutions: {
                oembed_url: data
              }
            }
          end
          @error
        end

        def self.valid_oembed_data?(data, maxwidth = nil, maxheight = nil)
          success = false

          @error ||= { error: {}, warning: {}, result: {} }

          if DataHashService.deep_blank?(data)

            (@error[:error][@template_key] ||= []) << {
              path: 'validation.errors.oembed_no_url'
            }
            return {error: @error, success:, oembed_url: nil, request_url: data}
          end

          oembed_url = nil

          providers = Rails.cache.fetch(DataCycleCore.oembed_providers['base_json'], expires_in: 1.week) do
            url = URI.parse(DataCycleCore.oembed_providers['base_json'])

            begin
              response = Net::HTTP.get(url)
              json_data = JSON.parse(response)
              json_data.index_by { |provider| provider['provider_url'] }
            rescue StandardError => e
              Rails.logger.error "Failed to fetch or parse JSON: #{e.message}"
              { } # Return nil or handle this case as needed
            end
          end

          additional_providers = DataCycleCore.oembed_providers['oembed_providers']&.index_by { |provider| provider['provider_url'] } || {}
          oembed_providers_map = providers.merge(additional_providers)

          oembed_providers = oembed_providers_map.values
          selected = oembed_providers.select do |provider|
            provider['endpoints'].any? do |endpoint|
              next false if endpoint.dig('schemes').blank?

              next if endpoint['formats'].present? && endpoint['formats'].exclude?('json')

              hit = endpoint['schemes'].any? do |scheme|
                Regexp.new('^' + Regexp.escape(scheme).gsub('\\*', '.*') + '$').match?(data)
              end
              provider['oembed_url'] = endpoint['url'] if hit
              hit
            end
          end

          if selected.count.zero?
            (@error[:error][@template_key] ||= []) << {
              path: 'validation.errors.oembed_no_provider',
              substitutions: {
                oembed_url: data
              }
            }
          elsif selected.count > 1
            (@error[:error][@template_key] ||= []) << {
              path: 'validation.errors.oembed_too_many_providers',
              substitutions: {
                oembed_url: data,
                oembed_found: selected.map { |sel| "#{sel['provider_name']} (#{sel['provider_url']})" }.join(', ')
              }
            }
          else
            success = true
            oembed_url = "#{selected.first['oembed_url'].sub('{format}', 'json')}?url=#{data}#{maxwidth.present? ? "&maxwidth=#{maxwidth}" : ''}#{maxheight.present? ? "&maxheight=#{maxheight}" : ''}"
            @error = { error: {}, warning: {}, result: {} }
          end

          {error: @error, success:, oembed_url:}
        end

        private

        def required(data, value)
          (@error[:error][@template_key] ||= []) << { path: 'validation.errors.required' } if value && DataHashService.deep_blank?(data)
        end

        def soft_required(data, value)
          (@error[:warning][@template_key] ||= []) << { path: 'validation.warnings.required' } if value && DataHashService.deep_blank?(data)
        end
      end
    end
  end
end
