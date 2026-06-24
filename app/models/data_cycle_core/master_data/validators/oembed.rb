# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Validators
      # Validator for oEmbed URLs and data resolution.
      #
      # Handles validation of URLs, provider selection, oEmbed endpoint resolution,
      # and transformation of oEmbed responses into usable data structures.
      class Oembed < BasicValidator
        # Initializes the validator.
        #
        # @param data [String, nil] The oEmbed URL to validate
        # @param template [Hash] Validation template containing rules
        # @param template_key [String] Key used for error grouping
        # @param strict [Boolean] Whether strict validation mode is enabled
        # @param content [Object, nil] Optional content context
        # @param validate_now [Boolean] Whether to run validation immediately
        def initialize(data = nil, template = {}, template_key = '', strict = false, content = nil, validate_now: true)
          @content = content
          @error = { error: {}, warning: {}, result: {} }
          @template_key = template_key || 'oembed'
          validate(data, template, strict) if validate_now
        end

        # Validates oEmbed input data.
        #
        # Determines whether the input is a valid URL, resolves oEmbed data,
        # and applies additional template-based validations.
        #
        # @param data [String, nil] Input URL
        # @param template [Hash] Validation template
        # @param _strict [Boolean] Unused strict flag
        # @return [Hash] Validation result containing errors, warnings, and result
        def validate(data, template, _strict = false)
          if data.blank?
            category = if template.dig('validations', 'required')
                         :error
                       else
                         (template.dig('validations', 'soft_required') ? :warning : :result)
                       end
            if [:error, :warning].include?(category)
              (@error[category][@template_key] ||= []) << {
                path: 'validation.errors.oembed_no_url',
                substitutions: {
                  oembed_url: data
                }
              }
            end

            @error[:result][@template_key] = [] if category == :result
          else
            uri = parsed_url(data)
            valid_url = uri.respond_to?(:scheme) && uri.respond_to?(:host) &&
                        uri&.scheme.present? && uri&.host.present? &&
                        ['https', 'http'].include?(uri.scheme) && uri.host.present?

            if valid_url
              data_valid = valid_oembed_data?(data)
              if data_valid[:success] == true
                if template.key?('validations')
                  template['validations'].each_key do |key|
                    validate_with_method(key, data, template['validations'][key])
                  end
                end
                @error[:result][@template_key] = Array.wrap(data_valid[:oembed_url])
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
          end

          @error
        end

        # Resolves and validates oEmbed data from a URL.
        #
        # Selects an appropriate provider and constructs the oEmbed endpoint URL.
        #
        # @param data [String] Input URL
        # @param maxwidth [Integer, nil] Optional max width
        # @param maxheight [Integer, nil] Optional max height
        # @return [Hash] Result with success flag, oembed_url, and errors
        def valid_oembed_data?(data, maxwidth = nil, maxheight = nil) # rubocop:disable Naming/PredicateMethod
          success = false

          if DataHashService.deep_blank?(data)
            (@error[:error][@template_key] ||= []) << {
              path: 'validation.errors.oembed_no_url'
            }

            return { error: @error, success:, oembed_url: nil, request_url: data }
          end

          oembed_url = nil
          selected = select_provider(data)

          if selected.none?
            (@error[:error][@template_key] ||= []) << {
              path: 'validation.errors.oembed_no_provider',
              substitutions: {
                oembed_url: data
              }
            }
          elsif selected.many?
            (@error[:error][@template_key] ||= []) << {
              path: 'validation.errors.oembed_too_many_providers',
              substitutions: {
                oembed_url: data,
                oembed_found: selected.map { |sel| "#{sel['provider_name']} (#{sel['provider_url']})" }.join(', ')
              }
            }
          else
            success = true

            if selected.first['oembed_url'].include? '{dcThingOembed}'
              thing_id = data.split('/things/')&.last&.split('?')&.first
              if thing_id.blank? || DataCycleCore::Thing.where(id: thing_id).blank?
                success = false

                (@error[:error][@template_key] ||= []) << {
                  path: 'validation.errors.oembed_thing_not_found'
                }
                oembed_url = nil
              else
                oembed_url = "#{selected.first['oembed_url'].sub('{format}', 'json').sub('{dcThingOembed}', DataCycleCore::UrlService.instance.oembed_url.to_s)}?thing_id=#{thing_id}#{"&maxwidth=#{maxwidth}" if maxwidth.present?}#{"&maxheight=#{maxheight}" if maxheight.present?}"
              end
            else
              oembed_url = "#{selected.first['oembed_url'].sub('{format}', 'json')}?url=#{data}#{"&maxwidth=#{maxwidth}" if maxwidth.present?}#{"&maxheight=#{maxheight}" if maxheight.present?}"
            end

            @error = { error: {}, warning: {}, result: {} } if success
          end

          { error: @error, success:, oembed_url: }
        end

        # Builds oEmbed response from a Thing ID.
        #
        # Resolves provider configuration and dynamically constructs oEmbed output.
        #
        # @param thing_id [String, Integer] Identifier of the Thing
        # @return [Hash] Result with oEmbed data or error
        def valid_oembed_from_thing_id(thing_id)
          success = false
          error_path = ''
          thing = DataCycleCore::Thing.find(thing_id)
          provider = select_provider(DataCycleCore::UrlService.instance.thing_url(id: thing_id))&.first
          oembed_output = provider['output'].select { |o| o['template_names']&.include?(thing.template_name) }&.first if provider.present?
          thing_url = parsed_url(thing.url) if thing.respond_to?(:url)

          if provider.present? && oembed_output.present? && oembed_output['type'].present? && oembed_output['version'].present?
            override_provider = oembed_output['override_provider'].select { |po|
              thing_url.present? && po['host_match'].present? && thing_url.host&.include?(po['host_match'])
            }&.first || {}

            oembed_base = oembed_output.merge(override_provider).except(:override_provider, :template_names, :version, :host_match)

            oembed_addition = {
              provider_name: override_provider['provider_name'] || thing.external_source&.name || oembed_output['provider_name'] || ENV['COMPOSE_PROJECT_NAME'] || 'dataCycle',
              provider_url: override_provider['provider_url'] || (thing.external_source.present? ? '{url}' : oembed_output['provider_url'] || DataCycleCore::UrlService.instance.root_url)
            }

            oembed = oembed_base.merge(oembed_addition)

            # BEGIN
            # in case the url used in the dc thing points to a third party provider, e.g. YouTube Link for a Webcam URL

            remote_url = oembed[:url].sub('{', '').sub('}', '').split('|').filter_map { |url| thing.respond_to?(url) ? thing.send(url) : nil }.first

            is_third_party_provider = select_provider(remote_url)&.present?

            if is_third_party_provider
              valid_data = valid_oembed_data?(remote_url, oembed[:max_width], oembed[:max_height])[:oembed_url]
              oembed_url = parsed_url(valid_data)

              res = Rails.cache.fetch(oembed_url, expires_in: 1.day, skip_nil: true) do
                res = Net::HTTP.get_response(oembed_url)
                res.is_a?(Net::HTTPSuccess) ? res.body : nil
              end

              oembed = JSON.parse(res) if res.present?
              @error = { error: {}, warning: {}, result: {} }

              return { error: @error, success:, oembed: }
            end

            # END

            oembed_output
              .except('template_names', 'override_provider', 'default_height', 'default_width')
              .each do |k, v|
              next if [].include?(k)

              v = oembed[k.to_sym] || v

              replaced_value = v&.gsub(/\{([^}]+)}/) do
                s = ::Regexp.last_match(1).split('|').map(&:strip).find do |key|
                  thing.present? ? ((thing.respond_to?(key) && thing.send(key).present?) || key.match(/^val:/) || key.match(/^from:/)) : false
                end

                if s.present? && s.match(/^from:/)
                  from = s.sub('from:', '').strip.split(':')

                  case from.first
                  when 'url', 'thumbnail_url'
                    if from.size == 2
                      target_prop = (oembed[from[0]&.to_sym] || oembed_output[from[0]&.to_sym])&.gsub(/[{}]/, '')&.split('|')&.find { |key| thing.respond_to?(key) && thing.send(key).present? }
                      target_url = target_prop&.then { |key| thing.send(key) }
                      s = target_url.present? ? from_url(target_url, from[1]) : oembed["default_#{from[1]}"]
                    else
                      s = nil
                    end
                  else
                    s = nil
                  end
                  s
                elsif s.present? && s.match(/^val:/)
                  s = s.sub('val:', '').strip
                  s.match?(/^\d+$/) ? s : oembed[s.to_sym].to_s
                elsif thing.present? && s.present? && thing.respond_to?(s)
                  received = thing.send(s)
                  next if received.blank?

                  if (received.is_a?(Array) || received.is_a?(ActiveRecord::Relation)) && received.any?
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
                      result = received.join(', ')
                    end
                  elsif received.is_a?(DataCycleCore::Thing)
                    result = received.respond_to?(:name) ? received.name : received.id
                  else
                    result = received.to_s
                  end

                  result
                end
              end

              if replaced_value.present?
                oembed[k.to_sym] = ['height', 'width'].include?(k) ? replaced_value.to_i : replaced_value
              end
            end

            oembed.compact!

            if oembed[:provider_url] == '{url}'
              provider_uri = parsed_url(oembed[:url])
              oembed[:provider_url] = "#{provider_uri.scheme}://#{provider_uri.host}"
            end

            oembed[:html] = oembed[:html]&.gsub(/\s+\w+='\s*'/, '') if oembed[:html].present?

            oembed = oembed.except(:default_height, :default_width).reject { |_k, v| v.to_s.match?(/^\{.*\}$/) }

            success = true
          else
            error_path = 'validation.errors.oembed_thing_not_found'
          end

          if success == true
            @error = { error: {}, warning: {}, result: {} }
            { error: @error, success:, oembed: }
          else
            (@error[:error][@template_key] ||= []) << { path: error_path }
            { error: @error, success:, oembed_url: nil, requested_thing_id: thing_id }
          end
        rescue ActiveRecord::RecordNotFound
          (@error[:error][@template_key] ||= []) << { path: 'validation.errors.oembed_thing_not_found' }
          { error: @error, success:, oembed_url: nil, requested_thing_id: thing_id }
        end

        # Selects matching oEmbed providers for a given URL.
        #
        # @param data [String] Input URL
        # @return [Array<Hash>] Matching provider definitions
        def select_provider(data)
          providers&.values&.select do |provider|
            provider['endpoints']&.any? do |endpoint|
              next if endpoint['schemes'].blank?
              next if endpoint['formats'].present? && endpoint['formats'].exclude?('json')

              hit = endpoint['schemes'].any? do |scheme|
                next if scheme.class.name != 'String' || data.class.name != 'String'

                Regexp.new("^#{Regexp.escape(scheme).gsub('\*', '.*')}", Regexp::IGNORECASE).match?(data)
              end

              provider['oembed_url'] = endpoint['url'] if hit
              hit
            end
          end
        end

        # Returns configured oEmbed providers, including cached base providers
        # and additional custom providers.
        #
        # @return [Hash] Provider definitions indexed by provider URL
        def providers
          return @providers if defined?(@providers)

          base_providers = Rails.cache.fetch(DataCycleCore.oembed_providers['base_json'], expires_in: 1.week) do
            url = parsed_url(DataCycleCore.oembed_providers['base_json'])

            begin
              response = Net::HTTP.get(url)
              json_data = JSON.parse(response)
              json_data.index_by { |provider| provider['provider_url'] }
            rescue StandardError => e
              Rails.logger.error "Failed to fetch or parse JSON: #{e.message}"
            end
          end

          additional_providers = DataCycleCore.oembed_providers['oembed_providers']
            &.index_by { |provider| provider['provider_url'] } || {}

          @providers = base_providers.merge(additional_providers)
        end

        # Extracts image dimensions from a URL.
        #
        # @param url [String] Image URL
        # @param property [String] 'width' or 'height'
        # @return [Integer, nil] Dimension value
        def from_url(url, property)
          size = FastImage.size(url)
          case property
          when 'height'
            size.present? && size.size == 2 ? size[1] : nil
          when 'width'
            size.present? && size.size == 2 ? size[0] : nil
          end
        end

        # Parses a URL string into a URI object.
        #
        # @param data [String] URL string
        # @return [Addressable::URI, nil] Parsed URI or nil if invalid
        def parsed_url(data)
          return nil if data.blank?

          Addressable::URI.parse(data)
        rescue Addressable::URI::InvalidURIError
          nil
        end

        private

        # Adds an error if required oEmbed data is missing.
        #
        # @param data [Object] Input data
        # @param value [Boolean] Required flag
        # @return [void]
        def required(data, value)
          (@error[:error][@template_key] ||= []) << { path: 'validation.errors.required' } if value && DataHashService.deep_blank?(data)
        end

        # Adds a warning if soft-required oEmbed data is missing.
        #
        # @param data [Object] Input data
        # @param value [Boolean] Soft-required flag
        # @return [void]
        def soft_required(data, value)
          (@error[:warning][@template_key] ||= []) << { path: 'validation.warnings.required' } if value && DataHashService.deep_blank?(data)
        end
      end
    end
  end
end
