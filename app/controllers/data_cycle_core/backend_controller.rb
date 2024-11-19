# frozen_string_literal: true

module DataCycleCore
  class BackendController < ApplicationController
    include DataCycleCore::FilterConcern
    authorize_resource class: false # from cancancan (authorize)
    before_action :load_last_filter, only: :index, if: -> { params.slice(:stored_filter, :f, :reset).blank? }
    before_action :load_stored_filter, only: :index, if: -> { params[:stored_filter].present? }
    prepend_before_action :load_previous_page, only: :index, if: :load_previous_page?

    def index
      set_instance_variables_by_view_mode(query: @query)
      save_filter if !@stored_filter.persisted? && request.format.html?

      respond_to do |format|
        format.html
        format.json { render json: { html: render_to_string(formats: [:html], layout: false, partial: 'data_cycle_core/application/count_or_more_results').strip } }
      end
    end

    def settings
    end
  end
end
