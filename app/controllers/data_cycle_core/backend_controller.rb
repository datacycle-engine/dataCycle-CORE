module DataCycleCore
  class BackendController < ApplicationController
    include DataCycleCore::Filter
    before_action :authenticate_user! # from devise (authenticate)
    authorize_resource class: false # from cancancan (authorize)

    def index
      if DataCycleCore.autoload_last_filter && params[:stored_filter].blank? && !params[:utf8] && current_user.stored_filters.size.positive?
        filter_id = current_user.stored_filters.order(created_at: :desc)&.first&.id
        @contents = apply_filter(filter_id: filter_id)
      elsif params[:stored_filter].blank?
        @contents = get_filtered_results
        @stored_filter = save_filter
      else
        @contents = apply_filter(filter_id: params[:stored_filter])
      end

      @creativeWork = CreativeWork.new
    end

    def settings
    end

    private

    def parse_classifications(class_array)
      grouping_class = {}
      class_array.each do |class_id|
        name = DataCycleCore::ClassificationAlias.find(class_id).classification_tree_label.name
        grouping_class[name] ||= []
        grouping_class[name].push(class_id)
      end
      grouping_class
    end
  end
end
