module DataCycleCore
  class Api::V1::ExternalSourcesController < Api::V1::ApiBaseController

    def update

      api_strategy = get_api_strategy
      content = params[:content].as_json

      updated = api_strategy.update content
      render json: {'updated' => updated}

    end

    def create

      api_strategy = get_api_strategy
      content = params[:content].as_json

      created = api_strategy.create content
      render json: {'created' => created}

    end

    def destroy

      api_strategy = get_api_strategy

      deleted = api_strategy.delete external_sources_params[:external_key]
      render json: {'deleted' => deleted}

    end

    private

    def external_sources_params
      params.permit(:external_source_id, :type, :external_key, :token)
    end

    def get_api_strategy
      external_source = DataCycleCore::ExternalSource.find(external_sources_params[:external_source_id])
      import_config = external_source.config["import_config"].symbolize_keys
      api_strategy = import_config[:api_strategy].safe_constantize
      api_strategy.new(external_source, external_sources_params[:type], external_sources_params[:external_key])
    end

  end
end
