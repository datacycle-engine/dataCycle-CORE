module DataCycleCore
  class BackendController < ApplicationController
    include DataCycleCore::Filter
    before_action :authenticate_user! # from devise (authenticate)
    authorize_resource class: false # from cancancan (authorize)
    before_action :set_default_filter, only: :index, if: -> { DataCycleCore.features&.dig(:life_cycle, :default_filter).present? }

    def index
      if DataCycleCore.features&.dig(:autoload_last_filter) && params[:stored_filter].blank? && !params[:utf8] && current_user.stored_filters.size.positive?
        filter_id = current_user.stored_filters.order(created_at: :desc)&.first&.id
        @paginateObject = apply_filter(filter_id: filter_id).includes(content_data: [:display_classification_aliases, :translations, :watch_lists, :external_source]).page(params[:page])
        @total = @paginateObject.total_count
        @contents = @paginateObject.map(&:content_data)
      elsif params[:stored_filter].blank?
        @contents = get_filtered_results
        @stored_filter = save_filter
      else
        @paginateObject = apply_filter(filter_id: params[:stored_filter]).includes(content_data: [:display_classification_aliases, :translations, :watch_lists, :external_source]).page(params[:page])
        @total = @paginateObject.total_count
        @contents = @paginateObject.map(&:content_data)
      end
      # TODO: remove creativeWork variable
      @content = CreativeWork.new
    end

    def settings
    end

    private

    def set_default_filter
      @classification_array = [helpers.life_cycle_items&.dig(DataCycleCore.features&.dig(:life_cycle, :default_filter), :alias)&.id] if helpers.life_cycle_items.present? && (params[:classification].blank? || helpers.life_cycle_items.size { |o| params[:classification].map { |c| c[:selected] }.include?(o[:id]) }.zero?)
    end

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
