# frozen_string_literal: true

module DataCycleCore
  module Api
    module V4
      class ExternalSystemsController < ApiBaseController
        def show
          @content = DataCycleCore::Thing.find_by!(external_source_id: permitted_params[:external_source_id], external_key: permitted_params[:external_key])

          redirect_to api_v4_thing_path({ id: @content.id }.merge(params.except(:external_key, :external_source_id, :controller, :action).to_unsafe_hash))
        end

        def permitted_params
          @permitted_params ||= params.permit(*permitted_parameter_keys)
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
          super + [:external_source_id, :type, :external_key, :webhook_source]
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
