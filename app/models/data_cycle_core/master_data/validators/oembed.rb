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
            host = Rails.application.config.action_mailer.default_url_options.dig(:host)
            protocol = Rails.application.config.action_mailer.default_url_options.dig(:protocol)
            dc_thing_oembed_url = "#{protocol}://#{host}"

            if selected.first['oembed_url'].include? '{dcThingOembed}'
              thing_id = data.split('/things/')&.last&.split('?')&.first
              if thing_id.blank? || DataCycleCore::Thing.where(id: thing_id).blank?
                success = false

                (@error[:error][@template_key] ||= []) << {
                  path: 'validation.errors.oembed_thing_not_found'
                }
                oembed_url = nil
              else
                oembed_url = "#{selected.first['oembed_url'].sub('{format}', 'json').sub('{dcThingOembed}', "#{dc_thing_oembed_url}/oembed")}?thing_id=#{thing_id}#{maxwidth.present? ? "&maxwidth=#{maxwidth}" : ''}#{maxheight.present? ? "&maxheight=#{maxheight}" : ''}"
              end

            else
              oembed_url = "#{selected.first['oembed_url'].sub('{format}', 'json')}?url=#{data}#{maxwidth.present? ? "&maxwidth=#{maxwidth}" : ''}#{maxheight.present? ? "&maxheight=#{maxheight}" : ''}"
            end

            @error = { error: {}, warning: {}, result: {} } if success
          end

          {error: @error, success:, oembed_url:}
        end

        def self.valid_oembed_from_thing_id(thing_id)
          success = false
          error_path = ''

          @error ||= { error: {}, warning: {}, result: {} }
          thing = DataCycleCore::Thing.where(id: thing_id).first
          thing_template = DataCycleCore::ThingTemplate.find_by(template_name: thing.template_name) if thing.present?
          oembed_feature = thing_template.schema.dig('features', 'oembed') if thing_template.present?
          oembed_output = oembed_feature.dig('output') if oembed_feature.present?

          error_path = 'validation.errors.oembed_thing_not_found' if thing_id.blank? || thing.blank? || oembed_feature.blank? || oembed_feature.dig('allowed') != true

          if oembed_feature.present? && oembed_output.present? && oembed_output.dig('type').present? && oembed_output.dig('version').present?

            oembed = {
              provider_name: 'dataCycle',
              provider_url: "#{Rails.application.config.action_mailer.default_url_options.dig(:protocol)}://#{Rails.application.config.action_mailer.default_url_options.dig(:host)}"
            }

            oembed_output.each do |k, v|
              replaced_value = v.gsub(/\{([^}]+)}/) do
                s = ::Regexp.last_match(1).split('|').map(&:strip).find do |key|
                  thing.present? ? thing.respond_to?(key) && thing.send(key).present? : false
                end
                if thing.present? && s.present? && thing.respond_to?(s)
                  received = thing.send(s)
                  result = ''

                  if received.is_a?(Array) && received.size.positive?
                    received.first.is_a?(Hash) ? result = received.map(&:name).concat(', ') : received.map(&:to_s).concat(', ')
                  elsif received.is_a?(Hash)
                    result = received.respond_to?(:name) ? received.name : received.id
                  else
                    result = received.to_s
                  end
                  result
                end
              end
              oembed[k.to_sym] = replaced_value if replaced_value.present?
            end
            oembed = oembed.compact
            success = true
          else
            error_path = 'validation.errors.oembed_thing_not_found'
          end

          if success == true
            @error = { error: {}, warning: {}, result: {} }
            {error: @error, success:, oembed:}
          else
            (@error[:error][@template_key] ||= []) << {
              path: error_path
            }
            { error: @error, success:, oembed_url: nil, requested_thing_id: thing_id }
          end
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
