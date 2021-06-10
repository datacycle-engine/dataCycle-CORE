# frozen_string_literal: true

module DataCycleCore
  module Api
    module V4
      class ExternalSystemsController < ApiBaseController
        def show
          external_system_id = DataCycleCore::ExternalSystem.find_by(identifier: permitted_params[:external_source_id])&.id || permitted_params[:external_source_id]

          content = DataCycleCore::Thing.by_external_key(external_system_id, permitted_params[:external_key]).first

          raise ActiveRecord::RecordNotFound if content.nil?

          redirect_to api_v4_thing_path({ id: content.id }.merge(params.except(:external_key, :external_source_id, :controller, :action, :format).to_unsafe_hash))
        end

        def permitted_params
          @permitted_params ||= params.permit(*permitted_parameter_keys)
        end

        def search_availability
          external_system = DataCycleCore::ExternalSystem.find_by(id: permitted_params[:external_source_id])
          error = 'Only available for Feratel data.' if external_system.identifier != 'feratel'

          temp_params = { days: '7', units: '1', from: '2021-08-20', to: '2021-08-30', adults: '1' }
          credentials = { options: temp_params }.merge(Array.wrap(external_system.credentials).first.symbolize_keys)
          endpoint = DataCycleCore::Generic::Feratel::Endpoint.new(credentials)
          search_data = endpoint.search_availabilities
          content_ids = DataCycleCore::Thing.where(external_key: search_data.map { |i| i.dig('id') })&.ids

          if error.present?
            render plain: { error: error }.to_json, content_type: 'application/json', status: :bad_request
          else
            params = permitted_params
              .except(:external_source_id, :controller, :action, :format, :endpoint_id)
              .merge('filter' => { 'contentId' => { 'in' => content_ids } }, id: permitted_params[:endpoint_id])
              .to_hash
              .symbolize_keys
            redirect_to api_v4_stored_filter_path(params)
          end
        end

        def update
          strategy, external_system = api_strategy
          render(json: { error: 'endpoint not active' }, status: :not_found) && return if strategy.nil?
          contents = Array.wrap(content_params.as_json)

          responses = contents.map do |content|
            strategy.update(content, external_system)
          end

          errors = responses.select { |i| i[:error].present? }

          render plain: responses.to_json, content_type: 'application/json', status: errors.size.positive? ? :bad_request : :ok
        end

        # def create
        #   strategy = api_strategy
        #   content = content_params.as_json
        #
        #   created = strategy.create content
        #
        #   # FIXME: Jbuilder Bug: tries to render jbuilder partial
        #   render plain: { 'created' => created }.to_json, content_type: 'application/json'
        # end

        def destroy
          strategy, external_system = api_strategy
          render(json: { error: 'endpoint not active' }, status: :not_found) && return if strategy.nil?
          contents = Array.wrap(content_params.as_json)

          responses = contents.map do |content|
            strategy.delete(content, external_system)
          end

          errors = responses.select { |i| i[:error].present? }

          render plain: responses.to_json, content_type: 'application/json', status: errors.size.positive? ? :bad_request : :ok
        end

        private

        def content_params
          params.require(:@graph)
        end

        def permitted_parameter_keys
          super + [:external_source_id, :type, :external_key, :webhook_source, :endpoint_id, :days, :units, :from, :to, :adults]
        end

        def api_strategy
          external_system = DataCycleCore::ExternalSystem.find(permitted_params[:external_source_id])
          api_strategy = DataCycleCore.allowed_api_strategies.find { |object| object == external_system.config['api_strategy'] }

          return api_strategy&.constantize&.new(external_system, permitted_params[:type], permitted_params[:external_key], permitted_params[:token]), external_system
        end
      end
    end
  end
end
