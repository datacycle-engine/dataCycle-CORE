module DataCycleCore
  class Api::V1::ContentsController < Api::V1::ApiBaseController
    def show
      render partial: params[:type].singularize, locals: { object: Object.const_get("DataCycleCore::#{params[:type].classify}").find(params[:id]) }
    end
  end
end
