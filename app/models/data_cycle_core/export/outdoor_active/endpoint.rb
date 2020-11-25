# frozen_string_literal: true

module DataCycleCore
  module Export
    module OutdoorActive
      class Endpoint < DataCycleCore::Export::Common::Endpoint::GenericEndpoint
        def initialize(**options)
          super

          @key = options.dig(:key)
        end

        def update_request(data:, external_system_data: {})
          response = connection.get do |req|
            req.url File.join([@host])

            req.params['key'] = @key
            req.params['ids'] = data.id
          end

          raise DataCycleCore::Generic::Common::Error::EndpointError.new("error sending data to #{File.join([@host, @key])}, external_system_data: #{external_system_data}", response) unless response.success?

          response_body = Nokogiri::XML(response.body)
          job_id = response_body.children.first.attribute('jobid').value
          external_system_data.merge(
            {
              'job_id' => job_id,
              'job_status' => 'waiting',
              'external_source_id' => data.external_source.id
            }
          ).reject { |_k, v| v.blank? }
        end

        def job_status_request(data:, external_system_data:)
          job_id = external_system_data.dig('job_id')
          response = connection.get do |req|
            req.url File.join([@host])
            req.params['jobid'] = job_id
          end

          raise DataCycleCore::Generic::Common::Error::EndpointError.new("error sending data to #{File.join([@host, job_id])} ", response) unless response.success?

          parse_job_status_response_body(raw_response_body: response.body, job_id: job_id).merge({ 'external_source_id' => data.external_source.id })
        end

        def parse_job_status_response_body(raw_response_body:, job_id:)
          response_body = Nokogiri::XML(raw_response_body)

          raise DataCycleCore::Generic::Common::Error::EndpointError.new('Cannot process job status with multiple items', response_body) if response_body.xpath('//details//content[@type!="imagemeta"]').count > 1

          job_status = response_body.children.first.attribute('state').value

          case job_status
          when 'running', 'jobnotfound'
            {
              'job_id' => job_id,
              'job_status' => job_status,
              'seen_at' => Time.zone.now
            }
          when 'failed'
            error_msg = response_body.children.first.content

            {
              'job_id' => nil,
              'last_job_id' => job_id,
              'seen_at' => Time.zone.now,
              'job_status' => job_status,
              'job_message' => error_msg
            }
          when 'done'
            outdoor_active_id = response_body.xpath('//details//content[@type!="imagemeta"]//@cmsId').first.to_s
            errors = response_body.children.first.xpath('//details//content[@type!="imagemeta"]//invalidContent//text()').map(&:to_s)
            warnings = response_body.children.first.xpath('//details//content[@type!="imagemeta"]//warning//text()').map(&:to_s)

            {
              'job_id' => nil,
              'last_job_id' => job_id,
              'seen_at' => Time.zone.now,
              'outdoor_active_id' => errors.empty? ? outdoor_active_id : nil,
              'job_status' => errors.empty? ? 'done' : 'failed',
              'errors' => errors,
              'warnings' => warnings
            }.reject { |_k, v| v.blank? }
          else
            raise DataCycleCore::Generic::Common::Error::EndpointError.new("Unknow job state '#{job_status}'", nil)
          end
        end
      end
    end
  end
end
