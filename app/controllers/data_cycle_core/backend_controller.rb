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
    before_action :set_view_mode, only: :index

    def index
      @contents = get_filtered_results(@query, true)
      tmp_count = @contents.count_distinct
      @contents = @contents.distinct_by_content_id(@order_string).content_includes.page(params[:page])
      @stored_filter = save_filter if params[:stored_filter].blank?
      @total = @contents.instance_variable_set(:@total_count, tmp_count)

      respond_to do |format|
        format.html
        format.js { render 'data_cycle_core/application/more_results' }
      end
    end

    def settings
    end
  end
end
