# frozen_string_literal: true

module DataCycleCore
  module Api
    module V1
      class ExternalSystemsController < Api::V1::ApiBaseController
        def show
          @content = DataCycleCore::Thing.find_by!(external_source_id: permitted_params[:external_source_id], external_key: permitted_params[:external_key])

          redirect_to thing_path(@content)
        end

        def update
          strategy = api_strategy
          content = content_params.as_json

          updated = strategy.update content

          # FIXME: Jbuilder Bug: tries to render jbuilder partial
          render plain: { 'updated' => updated }.to_json, content_type: 'application/json'
        end

        def create
          strategy = api_strategy
          content = content_params.as_json

          created = strategy.create content

          # FIXME: Jbuilder Bug: tries to render jbuilder partial
          render plain: { 'created' => created }.to_json, content_type: 'application/json'
        end

        def destroy
          strategy = api_strategy
          content = content_params.as_json

          deleted = strategy.delete content

          # FIXME: Jbuilder Bug: tries to render jbuilder partial
          render plain: { 'deleted' => deleted }.to_json, content_type: 'application/json'
        end

        private

        def content_params
          params.require(:content)
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
