# frozen_string_literal: true

module DataCycleCore
  class BackendController < ApplicationController
    include DataCycleCore::Filter
    before_action :authenticate_user! # from devise (authenticate)
    authorize_resource class: false # from cancancan (authorize)
    before_action :set_default_filter, only: :index, if: -> { DataCycleCore.features&.dig(:life_cycle, :default_filter).present? }

    def index
      if DataCycleCore.features&.dig(:autoload_last_filter) && params[:stored_filter].blank? && !params[:utf8] && current_user.stored_filters.size.positive?
        # TODO: fix when needed
        # filter_id = current_user.stored_filters.order(created_at: :desc)&.first&.id
        # @paginate_object = apply_filter(filter_id: filter_id).includes(content_data: [:display_classification_aliases, :translations, :watch_lists, :external_source]).page(params[:page])
        # @total = @paginate_object.total_count
        # @contents = @paginate_object.map(&:content_data)
      elsif params[:stored_filter].blank?
        @paginate_object = get_filtered_results.content_includes.page(params[:page])
        @stored_filter = save_filter
      else
        query = apply_filter(filter_id: params[:stored_filter])
        @paginate_object = get_filtered_results(query).content_includes.page(params[:page])
      end

      @paginate_object = @paginate_object

      @total = @paginate_object.total_count
      @contents = @paginate_object.map(&:content_data)

      @content = CreativeWork.new
    end

    def settings
    end
  end
end
