# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Validators
      class Oembed < BasicValidator
        def initialize(data, template, template_key = '', strict = false, content = nil)
          @content = content
          @error = { error: {}, warning: {}, result: {} }
          @template_key = template_key || 'oembed'
          @providers = { }
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
            if data_valid[:success] == true
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

          base_providers = Rails.cache.fetch(DataCycleCore.oembed_providers['base_json'], expires_in: 1.week) do
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
          @providers = (@providers || base_providers).merge(additional_providers)

          selected = select_provider(@providers.values, data)

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
            host = Rails.application.config.action_mailer.default_url_options[:host]
            protocol = Rails.application.config.action_mailer.default_url_options[:protocol]
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

          dc_host = "#{Rails.application.config.action_mailer.default_url_options[:protocol]}://#{Rails.application.config.action_mailer.default_url_options[:host]}"

          @error ||= { error: {}, warning: {}, result: {} }
          thing = DataCycleCore::Thing.where(id: thing_id).first

          provider = select_provider(@providers.values, "#{dc_host}/things/#{thing_id}")&.first
          oembed_output = provider['output'].select { |o| o['template_names']&.include?(thing.template_name) }&.first if provider.present?

          error_path = 'validation.errors.oembed_thing_not_found' if thing_id.blank? || thing.blank? || provider.blank?

          if provider.present? && oembed_output.present? && oembed_output['type'].present? && oembed_output['version'].present?

            oembed = {
              provider_name: thing.external_source.presence&.name || provider['provider_name'] || Rails.application.config.session_options[:key].sub(/^_/, '').sub('_session', '') || 'dataCycle',
              provider_url: thing.external_source.present? ? '{url}' : (provider['provider_url'] || dc_host)
            }

            oembed_output.each do |k, v|
              next if k == 'template_names'
              replaced_value = v.gsub(/\{([^}]+)}/) do
                s = ::Regexp.last_match(1).split('|').map(&:strip).find do |key|
                  thing.present? ? ((thing.respond_to?(key) && thing.send(key).present?) || key.match(/^val:/)) : false
                end
                if s.present? && s.match(/^val:/)
                  s.sub('val:', '').strip
                elsif thing.present? && s.present? && thing.respond_to?(s)
                  received = thing.send(s)
                  return null if received.blank?
                  if (received.is_a?(Array) || received.is_a?(ActiveRecord::Relation)) && received.size.positive?
                    if received.first.is_a?(Hash) || received.first.is_a?(DataCycleCore::Thing)
                      result = received.map do |r|
                        if k == 'thumbnail_url' && s == 'video'
                          r&.preview_url || r&.name
                        elsif ['video', 'image'].include?(s)
                          r&.content_url || r&.name
                        else
                          r.name
                        end
                      end
                      result = result.first if ['html', 'url'].include?(k)
                      result = result.is_a?(Array) ? result.join(', ') : result.to_s
                    else
                      result = received.map(&:to_s).join(', ')
                    end
                  elsif received.is_a?(Hash) || received.is_a?(DataCycleCore::Thing)
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

            if oembed[:provider_url] == '{url}'
              provider_uri = URI.parse(oembed[:url])
              oembed[:provider_url] = "#{provider_uri.scheme}://#{provider_uri.host}"
            end

            oembed[:html] = oembed[:html].gsub(/\s+\w+='\s*'/, '') if oembed[:html].present?

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

        def self.select_provider(oembed_providers, data)
          oembed_providers.select do |provider|
            provider['endpoints'].any? do |endpoint|
              next false if endpoint['schemes'].blank?

              next if endpoint['formats'].present? && endpoint['formats'].exclude?('json')

              hit = endpoint['schemes'].any? do |scheme|
                Regexp.new('^' + Regexp.escape(scheme).gsub('\\*', '.*') + '$').match?(data)
              end
              provider['oembed_url'] = endpoint['url'] if hit
              hit
            end
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
