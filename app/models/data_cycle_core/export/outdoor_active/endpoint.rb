# frozen_string_literal: true

module DataCycleCore
  module Export
    module OutdoorActive
      class Endpoint < DataCycleCore::Export::Common::Endpoint::GenericEndpoint
        def initialize(**options)
          @host = options.dig(:host)
          @key = options.dig(:key)
        end

        def update_request(data:, external_system_data: {})
          response = Faraday.new.get do |req|
            req.url File.join([@host])

            req.params['key'] = @key
            req.params['ids'] = data.id
          end

          raise DataCycleCore::Generic::Common::Error::EndpointError.new("error sending data to #{File.join([@host, @key])}, external_system_data: #{external_system_data}", response) unless response.success?

          response_body = Nokogiri::XML(response.body)
          job_id = response_body.children.first.attribute('jobid').value
          external_system_data.merge!({ 'job_id' => job_id, 'external_source_id' => data.external_source.id })
        end

        def job_status_request(data:, external_system_data:)
          job_id = external_system_data.dig('job_id')
          response = Faraday.new.get do |req|
            req.url File.join([@host])
            req.params['jobid'] = job_id
          end

          raise DataCycleCore::Generic::Common::Error::EndpointError.new("error sending data to #{File.join([@host, job_id])} ", response) unless response.success?

          response_body = Nokogiri::XML(response.body)
          job_status = response_body.children.first.attribute('state').value
          case job_status
          when 'jobnotfound'
            { 'job_id' => job_id, 'job_status' => job_status, 'external_source_id' => data.external_source.id }
          when 'running'
            { 'job_id' => job_id, 'job_status' => job_status, 'external_source_id' => data.external_source.id }
          when 'done'
            outdoor_active_id = response_body.children.first.xpath('//details//content').attribute('cmsId').value
            warnings = response_body.children.first.xpath('//details//content//warning').to_s
            { 'outdoor_active_id' => outdoor_active_id, 'job_status' => job_status, 'warnings' => warnings, 'external_source_id' => data.external_source.id }
          when 'failed'
            error_msg = response_body.children.first.content
            { 'job_id' => job_id, 'job_status' => job_status, 'job_message' => error_msg, 'external_source_id' => data.external_source.id }
          else
            raise DataCycleCore::Generic::Common::Error::EndpointError, "Unknow state for job: #{job_id} #{response}", response
          end
        end
      end
    end
  end
end
