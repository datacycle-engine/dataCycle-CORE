# frozen_string_literal: true

module DataCycleCore
  module Export
    module Onlim
      class Endpoint < DataCycleCore::Export::Common::Endpoint::GenericEndpoint
        include DataCycleCore::Engine.routes.url_helpers

        DEFAULT_ATTRIBUTES = [['id'], ['name'], ['geo'], ['address']].freeze # , ['description']
        ATTRIBUTE_FILTER = {
          'Event' => [['eventSchedule']],
          'Gastronomischer Betrieb' => [],
          'POI' => [],
          'Tour' => [],
          'Unterkunft' => [],
          'Bild' => [
            ['name'], ['contentUrl'], ['thumbnailUrl'], ['width'], ['height'],
            ['fileFormat'], ['uploadDate'], ['copyrightNotice'], ['copyrightYear']
          ],
          'Person' => [],
          'Organization' => []
        }.freeze

        DEFAULT_INCLUDE = [['image', 'copyrightHolder'], ['sdPublisher'], ['copyrightHolder']].freeze # ['dc:classification', 'skos:inScheme'],
        INCLUDE_FILTER = {
          'Event' => [['eventSchedule']],
          'Gastronomischer Betrieb' => [],
          'POI' => [['author']],
          'Tour' => [],
          'Unterkunft' => []
        }.freeze

        def self.serialize_data(data)
          json = DataCycleCore::Api::V4::ContentsController.renderer.new(
            http_host: Rails.application.config.action_mailer.default_url_options.dig(:host),
            https: Rails.application.config.force_ssl
          ).render(
            assigns: {
              content: data,
              language: ['de'], # TODO: Mehrsprachigkeit!
              language_mode: 'expanded',
              fields_parameters: DEFAULT_ATTRIBUTES + (ATTRIBUTE_FILTER[data.template_name] || []).uniq,
              expand_language: true,
              field_filter: true,
              include_parameters: DEFAULT_INCLUDE + (INCLUDE_FILTER[data.template_name] || []).uniq, # included data
              api_version: 4,
              permitted_params: {},
              api_context: 'api'
            },
            template: 'data_cycle_core/api/v4/contents/show',
            layout: false
          )

          hash = JSON[json]

          transformation =
            case data.template_name
            when 'Event'
              :to_event
            else
              :to_poi
            end

          hash = DataCycleCore::Export::Onlim::Transformations.send(transformation, []).call(hash)
          hash
        end

        def initialize(**options)
          super

          @host = options.dig(:host)
          @end_point = options.dig(:end_point)

          @api_key = options.dig(:api_key)
          @source_id = options.dig(:source_id)
          @publisher_id = options.dig(:publisher_id)
        end

        def update_request(data:, external_system_data: {})
          # do a UPSERT
          url = [@host, @end_point].join('/')
          verb = :put
          default_url_options[:host] = ENV['APP_HOST']
          default_url_options[:protocol] = ENV['APP_PROTOCOL']
          ns = api_v4_universal_url + '/'

          body = Endpoint.serialize_data(data)

          response = connection.send(verb) do |req|
            req.url(url)

            req.headers['Content-Type'] = 'application/ld+json'
            req.headers['X-PUBLISHER'] = @publisher_id
            req.headers['X-DATASOURCE'] = @source_id
            req.headers['x-api-key'] = @api_key

            req.params['ns'] = ns if ns.present?

            req.body = body.to_json
          end

          raise DataCycleCore::Generic::Common::Error::EndpointError.new("error sending data to #{url}, external_system_data: #{external_system_data}", response) unless response.success?

          ap JSON.parse(response.body)

          job_id = JSON.parse(response.body)['message']

          raise DataCycleCore::Generic::Common::Error::EndpointError.new("could not parse a valid job_id form the response of this request: #{url}, external_system_data: #{external_system_data}", response) if job_id.blank?

          external_system_data.merge(
            {
              'job_id' => job_id,
              'job_status' => 'pending',
              'external_source_id' => DataCycleCore::ExternalSystem.find_by(identifier: 'onlim').id
            }
          ).reject { |_k, v| v.blank? }
        end

        def job_status_request(data:, external_system_data:)
          external_source = DataCycleCore::ExternalSystem.find_by(identifier: 'onlim')
          external_system_syncs_id = external_system_data.dig('external_system_syncs_id')
          if external_system_syncs_id.present?
            esd = DataCycleCore::ExternalSystemSync.find_by(id: external_system_syncs_id)
            external_system_data = (esd&.data || {}).merge({ 'external_system_syncs_id' => external_system_syncs_id })
          end

          job_id = external_system_data.dig('job_id')
          url = [@host, @end_point, job_id].join('/')
          response = connection.get do |req|
            req.url(url)

            req.headers['x-api-key'] = @api_key
            req.headers['X-DETAILED-REPORT'] = 'true'
          end

          raise DataCycleCore::Generic::Common::Error::EndpointError.new("error asking for status for #{url} ", response) unless response.success?

          status = JSON.parse(response.body)
          status = status.first if status.is_a?(::Array)
          operation = status.dig('operation')
          # ap status

          if status['running']
            external_system_data.merge(
              {
                'job_id' => job_id,
                'job_status' => 'pending',
                'external_source_id' => external_source.id,
                'operation' => operation,
                'message' => status
              }
            ).reject { |_k, v| v.blank? }
          elsif status['stored']
            # save all external_data
            update_children_external_system_data(status['affectedEntries'], data.id, external_source)
            external_system_data.merge(
              {
                'job_id' => job_id,
                'job_status' => 'success',
                'external_source_id' => external_source.id,
                'operation' => operation,
                'message' => status
              }
            ).reject { |_k, v| v.blank? }
          else
            external_system_data.merge(
              {
                'job_id' => job_id,
                'job_status' => 'failed',
                'external_source_id' => external_source.id,
                'operation' => operation,
                'message' => status
              }
            ).reject { |_k, v| v.blank? }
          end
        end

        def delete_request(data:, external_system_data: {}) # rubocop:disable Lint/UnusedMethodArgument
          # for now only main Dataset will be deleted als dependent Data are not touched.
          verb = :delete
          url = [@host, "api/ts/v1/kg/things/#{data.id}"].join('/')
          default_url_options[:host] = ENV['APP_HOST']
          default_url_options[:protocol] = ENV['APP_PROTOCOL']
          ns = api_v4_universal_url + '/'

          response = connection.send(verb) do |req|
            req.url(url)

            req.headers['Content-Type'] = 'application/ld+json'
            req.headers['X-PUBLISHER'] = @publisher_id
            req.headers['X-DATASOURCE'] = @source_id
            req.headers['x-api-key'] = @api_key

            req.params['ns'] = ns if ns.present?
            req.params['dryRun'] = false
          end

          if response.status.in?([204, 404, 200])
            { 'job_status' => 'success' }
          else
            { 'job_status' => 'failed'}
          end
        end

        def update_children_external_system_data(hash, thing_id, external_source)
          return if hash.blank?
          ids = hash
            .map { |i| i['id'] }
            .map { |i| i.split('/').last }

          ids = Array.wrap(ids) - [thing_id]
          return if ids.blank?
          DataCycleCore::Thing.where(id: ids).find_each do |thing|
            thing.add_external_system_data(external_source, {}, 'success', 'export', thing.id, false)
          end
        end
      end
    end
  end
end
