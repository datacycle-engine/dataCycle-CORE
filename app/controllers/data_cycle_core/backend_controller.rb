# frozen_string_literal: true

module DataCycleCore
  class BackendController < ApplicationController
    include DataCycleCore::Filter
    before_action :authenticate_user! # from devise (authenticate)
    authorize_resource class: false # from cancancan (authorize)
    before_action :load_last_filter, only: :index, if: proc {
      DataCycleCore::Feature::MainFilter.autoload_last_filter? &&
        params.slice(:stored_filter, :f, :reset).blank? &&
        current_user.stored_filters.exists?
    }
    before_action :load_stored_filter, only: :index, if: -> { params[:stored_filter].present? }

    def index
      set_instance_variables_by_view_mode(query: @query)
      save_filter unless @stored_filter.persisted? || request.xhr?

      respond_to do |format|
        format.html
        format.js { render 'data_cycle_core/application/more_results' }
      end
    end

    def settings
    end
  end
end
