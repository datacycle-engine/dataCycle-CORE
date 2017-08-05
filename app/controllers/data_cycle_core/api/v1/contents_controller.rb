module DataCycleCore
  class Api::V1::ContentsController < Api::V1::ApiBaseController
    def show
      @content = Object.const_get("DataCycleCore::#{params[:type].classify}")
        .includes({classifications: [], translations: []})
        .find(params[:id])

      render partial: params[:type].singularize, locals: { object: @content }
    end
  end
end
