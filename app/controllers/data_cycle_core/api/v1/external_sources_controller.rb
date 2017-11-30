module DataCycleCore
  class Api::V1::ExternalSourcesController < Api::V1::ApiBaseController

    def update

      api_strategy = get_api_strategy
      content = params[:content].as_json

      updated = api_strategy.update content

      #execute_after_update_webhooks updated

      # FIXME: Jbuilder Bug: tries to render jbuilder partial
      render plain: {'updated' => updated}.to_json, content_type: 'application/json'

    end

    def create

      api_strategy = get_api_strategy
      content = params[:content].as_json

      created = api_strategy.create content
      # FIXME: Jbuilder Bug: tries to render jbuilder partial
      render plain: {'created' => created}.to_json, content_type: 'application/json'

    end

    def destroy

      api_strategy = get_api_strategy

      deleted = api_strategy.delete external_sources_params[:external_key]
      # FIXME: Jbuilder Bug: tries to render jbuilder partial
      render plain: {'deleted' => deleted}.to_json, content_type: 'application/json'

    end

    private

    def external_sources_params
      params.permit(:external_source_id, :type, :external_key, :token)
    end

    def get_api_strategy
      external_source = DataCycleCore::ExternalSource.find(external_sources_params[:external_source_id])
      api_strategy = external_source.config["api_strategy"].safe_constantize
      api_strategy.new(external_source, external_sources_params[:type], external_sources_params[:external_key])
    end

    # def execute_after_update_webhooks data
    #   Webhook::Update.execute_all(data)
    # end

  end
end
