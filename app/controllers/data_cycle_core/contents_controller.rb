module DataCycleCore
  class ContentsController < ApplicationController
    before_action :set_watch_list

    def new_embedded_object
      respond_to(:js)
    end

    def render_embedded_object
      object_type = DataCycleCore.content_tables.find{ |object| object ==  params[:definition]['storage_location'] }
      @object = ('DataCycleCore::'+object_type.singularize.classify).constantize.find_by(id: params[:id])
      respond_to(:js)
    end

    private

    def set_watch_list
      watch_list = DataCycleCore::WatchList.find(params[:watch_list_id]) if params[:watch_list_id]
      @watch_list = watch_list if can?(:manage, watch_list)
    end
  end
end
