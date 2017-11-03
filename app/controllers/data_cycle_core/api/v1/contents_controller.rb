module DataCycleCore
  class Api::V1::ContentsController < Api::V1::ApiBaseController
    def show
      @content = Object.const_get("DataCycleCore::#{params[:type].classify}")
        .includes({classifications: [], translations: []})
        .find(params[:id])
    end

    def update

      content = params.permit(:content)

      @content = Object.const_get("DataCycleCore::#{params[:type].classify}")
        .includes({classifications: [], translations: []})
        .find(params[:id])

      render json: @content.get_data_hash

    end
  end
end
