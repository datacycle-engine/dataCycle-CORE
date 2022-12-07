# frozen_string_literal: true

module DataCycleCore
  module Export
    module Onlim
      class Endpoint < DataCycleCore::Export::Common::Endpoint::GenericEndpoint
        include DataCycleCore::Engine.routes.url_helpers

        ATTRIBUTE_FILTER = {
          'POI' => [['id'], ['name'], ['description'], ['geo'], ['address']],
          'Unterkunft' => [['id'], ['name'], ['description'], ['geo'], ['address']],
          'Event' => [['id'], ['name'], ['description'], ['geo'], ['address'], ['eventSchedule']],
          'Gastronomischer Betrieb' => [['id'], ['name'], ['description'], ['geo'], ['address']],
          'Tour' => [['id'], ['name'], ['description'], ['geo'], ['address']]
        }.freeze

        INCLUDE_FILTER = {
          'Event' => [['eventSchedule']]
        }.freeze

        def initialize(**options)
          super

          @host = options.dig(:host)
          @end_point = options.dig(:end_point)

          @api_key = options.dig(:api_key)
          @source_id = options.dig(:source_id)
          @publisher_id = options.dig(:publisher_id)
        end

        def update_request(data:, external_system_data: {})
          url = [@host, @end_point].join('/')
          body = serialize_data(data)

          if external_system_data.present? && external_system_data['job_status'] == 'success' # update, not insert
            url = [url, "things/#{data.id}"].join('/')
            verb = :put
            default_url_options[:host] = ENV['APP_HOST']
            default_url_options[:protocol] = ENV['APP_PROTOCOL']
            ns = api_v4_universal_url + '/'
          else
            verb = :post
            ns = nil
          end

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

          job_id = JSON.parse(response.body)['message']

          raise DataCycleCore::Generic::Common::Error::EndpointError.new("could not parse a valid job_id form the response of this request: #{url}, external_system_data: #{external_system_data}", response) if job_id.blank?

          external_system_data.merge(
            {
              'job_id' => job_id,
              'job_status' => 'waiting',
              'external_source_id' => DataCycleCore::ExternalSystem.find_by(identifier: 'onlim').id
            }
          ).reject { |_k, v| v.blank? }
        end

        def job_status_request(data:, external_system_data:) # rubocop:disable Lint/unusedMethodArgument
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

          # ap status

          if status['running']
            # {
            # 	"id": "c180b387-3668-4289-af77-00962336e886",
            # 	"customer": "85fe4214-24ba-4980-a33c-4f05f4b3e9e8",
            # 	"dataSource": "87b1056c-dbf0-483e-872b-5e3eb187115a",
            # 	"importStartTime": "2022-06-28T14:24:46.147",
            # 	"processingDurationMs": 487,
            # 	"verified": true,
            # 	"valid": true,
            # 	"stored": true,
            # 	"running": false,
            # 	"existingObjects": false,
            # 	"importSize": 1632,
            # 	"operation": "UPDATE",
            # 	"numberOfStatements": 18,
            # 	"qatResponse": {
            # 		"score": 0.625,
            # 		"details": {
            # 			"4_3": "1",
            # 			"6_1": "0.5",
            # 			"11_2": "0",
            # 			"13_2": "1"
            # 		}
            # 	},
            # 	"verificationReport": {
            # 		"isValid": true,
            # 		"statusCode": 200,
            # 		"reports": [
            # 			{
            # 				"nodeId": "http://onlim.com/entity/587099459",
            # 				"usedDs": "https://semantify.it/ds/sloejGAwT",
            # 				"verificationReport": {
            # 					"verificationResult": "Valid"
            # 				}
            # 			}
            # 		],
            # 		"meta": {
            # 			"numEntities": 1,
            # 			"numVerifiedEntities": 1,
            # 			"numNonVerifiedEntities": 0,
            # 			"numValidEntities": 1,
            # 			"numValidWithWarningEntities": 0,
            # 			"numInvalidEntities": 0,
            # 			"numTotalErrors": 0
            # 		}
            # 	},
            # 	"affectedEntities": [
            # 		{
            # 			"id": "http://onlim.com/entity/genID_2812bb9f-0afd-4747-8f1e-e535d545253d"
            # 		},
            # 		{
            # 			"id": "http://onlim.com/entity/587099459"
            # 		}
            # 	]
            # }

            external_system_data.merge(
              {
                'job_id' => job_id,
                'job_status' => 'running',
                'external_source_id' => DataCycleCore::ExternalSystem.find_by(identifier: 'onlim').id,
                'message' => status['verificationReport']
              }
            ).reject { |_k, v| v.blank? }
          elsif !status['valid']
            external_system_data.merge(
              {
                'job_id' => job_id,
                'job_status' => 'failed',
                'external_source_id' => DataCycleCore::ExternalSystem.find_by(identifier: 'onlim').id,
                'message' => status['verificationReport']
              }
            ).reject { |_k, v| v.blank? }
          else
            external_system_data.merge(
              {
                'job_id' => job_id,
                'job_status' => 'success',
                'external_source_id' => DataCycleCore::ExternalSystem.find_by(identifier: 'onlim').id,
                'message' => status['verificationReport']
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

        def serialize_data(data)
          json = DataCycleCore::Api::V4::ContentsController.renderer.new(
            http_host: Rails.application.config.action_mailer.default_url_options.dig(:host),
            https: Rails.application.config.force_ssl
          ).render(
            assigns: {
              content: data,
              language: ['de'], # TODO: Mehrsprachigkeit!
              language_mode: 'expanded',
              fields_parameters: ATTRIBUTE_FILTER[data.template_name] || [],
              expand_language: true,
              field_filter: true,
              include_parameters: INCLUDE_FILTER[data.template_name] || [], # included data
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
          hash = DataCycleCore::Export::Onlim::Transformations.send(transformation).call(hash)
          hash
        end
      end
    end
  end
end
