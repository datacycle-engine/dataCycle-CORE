# frozen_string_literal: true

module DataCycleCore
  module Api
    module V2
      class ExternalSystemsController < Api::V2::ApiBaseController
        after_action :check_job_status, only: [:show]

        def show
          external_system = DataCycleCore::ExternalSystem.find(read_id(permitted_params.dig(:id)))
          raise unless external_system.identifier == 'outdooractive'

          ids = permitted_params.dig(:ids).split(',')
          contents = DataCycleCore::Thing.where(id: ids)

          deleted_content_ids = (ids - contents.pluck(:id))

          init_logging do |logger|
            logger.info("DataCycleCore::Api::V2.show for external_system: #{external_system.try(:name)}", nil)
            logger.info('controller show --> delete_items', deleted_content_ids.join(', ')) if deleted_content_ids.size.positive?
            logger.info('controller show --> update_items', contents.map(&:id).join(', ')) if contents.map(&:id).size.positive?
          end

          xml_content = DataCycleCore::Export::OutdoorActive::Transformations.to_xml(external_system, contents, deleted_content_ids)

          render xml: xml_content
        end

        def update
          strategy = api_strategy
          content = content_params.as_json

          updated = strategy.update content

          render plain: { 'updated' => updated }.to_json, content_type: 'application/json'
        end

        def create
          strategy = api_strategy
          content = content_params.as_json

          created = strategy.create content

          render plain: { 'created' => created }.to_json, content_type: 'application/json'
        end

        def destroy
          strategy = api_strategy
          content = content_params.as_json

          deleted = strategy.delete content

          render plain: { 'deleted' => deleted }.to_json, content_type: 'application/json'
        end

        private

        def permitted_parameter_keys
          super + [:id, :ids, :external_source_id, :type, :external_key, :webhook_source]
        end

        def content_params
          params.require(:content)
        end

        def check_job_status
          external_system = DataCycleCore::ExternalSystem.find(read_id(permitted_params.dig(:id)))
          ids = permitted_params.dig(:ids).split(',')
          items = DataCycleCore::Thing.where(id: ids)

          init_logging do |logger|
            logger.info("DataCycleCore::Api::V2.check_job_status for external_system: #{external_system.try(:name)}", nil)
          end

          items.each do |item|
            utility_object = DataCycleCore::Export::RefreshObject.new(external_system:)
            job_id = item.external_system_data(external_system, 'export', nil, false)&.dig('job_id')

            init_logging do |logger|
              logger.info("inspecting item id:#{item.id} --> job_id:#{job_id}", nil)
            end

            next if job_id.blank?
            DataCycleCore::Export::OutdoorActive::JobStatus.process(utility_object:, options: { job_id: })
          end
        end

        def init_logging
          logging = DataCycleCore::Generic::Logger::LogFile.new(:export)
          yield(logging)
        ensure
          logging.close if logging.respond_to?(:close)
        end

        def api_strategy
          external_source = DataCycleCore::ExternalSystem.find(read_id(permitted_params[:external_source_id]))
          api_strategy = DataCycleCore.allowed_api_strategies.find { |object| object == external_source.config['api_strategy'] }

          api_strategy&.constantize&.new(external_source, permitted_params[:type], permitted_params[:external_key], permitted_params[:token])
        end

        def read_id(id)
          translate_ids = {
            'ed979c1a-c582-40ea-adcd-a1ac0b6dd0db' => '4f0fb5fd-6adb-480e-91ed-1b04463cab4a'
          }
          translate_ids[id] || id
        end
      end
    end
  end
end
