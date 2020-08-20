# frozen_string_literal: true

module DataCycleCore
  module Api
    module V4
      class ExternalSystemsController < ApiBaseController
        def show
          @content = DataCycleCore::Thing.find_by!(external_source_id: permitted_params[:external_source_id], external_key: permitted_params[:external_key])

          redirect_to api_v4_thing_path({ id: @content.id }.merge(params.except(:external_key, :external_source_id, :controller, :action).permit!))
        end

        def permitted_params
          @permitted_params ||= params.permit(*permitted_parameter_keys)
        end

        def update
          strategy = api_strategy
          render(json: { error: 'endpoint not active' }, status: :not_found) && return if strategy.nil?
          contents = Array.wrap(content_params.as_json)

          external_source_id = DataCycleCore::ExternalSystem.find(permitted_params[:external_source_id]).try(:id)
          responses = contents.map do |content|
            strategy.update(content.merge('data_cycle_external_system_id' => external_source_id))
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
          strategy = api_strategy
          render(json: { error: 'endpoint not active' }, status: :not_found) && return if strategy.nil?
          contents = Array.wrap(content_params.as_json)

          external_source_id = DataCycleCore::ExternalSystem.find(permitted_params[:external_source_id]).try(:id)
          responses = contents.map do |content|
            strategy.delete(content.merge('data_cycle_external_system_id' => external_source_id))
          end

          errors = responses.select { |i| i[:error].present? }

          render plain: responses.to_json, content_type: 'application/json', status: errors.size.positive? ? :bad_request : :ok
        end

        private

        def content_params
          params.require(:@graph)
        end

        def permitted_parameter_keys
          super + [:external_source_id, :type, :external_key, :webhook_source]
        end

        def api_strategy
          external_source = DataCycleCore::ExternalSystem.find(permitted_params[:external_source_id])
          api_strategy = DataCycleCore.allowed_api_strategies.find { |object| object == external_source.config['api_strategy'] }

          api_strategy&.constantize&.new(external_source, permitted_params[:type], permitted_params[:external_key], permitted_params[:token])
        end
      end
    end
  end
end
