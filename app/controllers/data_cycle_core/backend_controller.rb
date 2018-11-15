# frozen_string_literal: true

module DataCycleCore
  class BackendController < ApplicationController
    include DataCycleCore::Filter
    before_action :authenticate_user! # from devise (authenticate)
    authorize_resource class: false # from cancancan (authorize)
    before_action :set_default_filter, only: :index, if: -> { DataCycleCore::Feature::LifeCycle.enabled? && DataCycleCore::Feature::LifeCycle.default_filter.present? }

    def index
      if DataCycleCore.features&.dig(:autoload_last_filter) && params[:stored_filter].blank? && !params[:utf8] && current_user.stored_filters.size.positive?
        # TODO: fix when needed
        # filter_id = current_user.stored_filters.order(created_at: :desc)&.first&.id
        # @contents = apply_filter(filter_id: filter_id).includes(content_data: [:display_classification_aliases, :translations, :watch_lists, :external_source]).page(params[:page])
        # @total = @contents.total_count
      elsif params[:stored_filter].blank?
        @contents = get_filtered_results
        @total = @contents.count_distinct
        @contents = @contents.distinct_by_content_id(@order_string).content_includes.page(params[:page])
        @stored_filter = save_filter
      else
        query = apply_filter(filter_id: params[:stored_filter])
        @contents = get_filtered_results(query)
        @total = @contents.count_distinct
        @contents = @contents.distinct_by_content_id(@order_string).content_includes.page(params[:page])
      end
      @total_pages = (@total.to_f / 25).ceil
      @content = DataCycleCore::Thing.new
    end

    def settings
    end
  end
end
