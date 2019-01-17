# frozen_string_literal: true

module DataCycleCore
  class BackendController < ApplicationController
    include DataCycleCore::Filter
    before_action :authenticate_user! # from devise (authenticate)
    authorize_resource class: false # from cancancan (authorize)
    before_action :load_last_filter, only: :index, if: proc {
      DataCycleCore::Feature::MainFilter.autoload_last_filter? &&
        params.except(:controller, :action).blank? &&
        current_user.stored_filters.exists?
    }
    before_action :load_stored_filter, only: :index, if: -> { params[:stored_filter].present? }
    before_action :set_default_filter, only: :index, if: proc {
      DataCycleCore::Feature::LifeCycle.enabled? &&
        DataCycleCore::Feature::LifeCycle.default_filter.present?
    }

    def index
      @contents = get_filtered_results(@query)
      @total = @contents.count_distinct
      @contents = @contents.distinct_by_content_id(@order_string).content_includes.page(params[:page])
      @stored_filter = save_filter if params[:stored_filter].blank?
      @total_pages = @total.fdiv(25).ceil
    end

    def settings
    end
  end
end
