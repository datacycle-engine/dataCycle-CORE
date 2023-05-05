# frozen_string_literal: true

module DataCycleCore
  class BackendController < ApplicationController
    include DataCycleCore::Filter
    authorize_resource class: false # from cancancan (authorize)
    before_action :load_last_filter, only: :index, if: proc {
      DataCycleCore::Feature::MainFilter.autoload_last_filter? &&
        params.slice(:stored_filter, :f, :reset).blank?
    }
    before_action :load_stored_filter, only: :index, if: -> { params[:stored_filter].present? }
    after_action :set_previous_page, only: :index, if: -> { params[:page].present? && params[:reset].blank? && @mode&.in?(['grid', 'list']) }
    prepend_before_action :load_previous_page, only: :index, if: lambda {
      DataCycleCore::Feature::MainFilter.autoload_last_filter? &&
        params.slice(:stored_filter, :f, :reset).blank? &&
        session[:previous_page].present? &&
        request.format.html?
    }

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

    private

    def set_previous_page
      session[:previous_page] = params[:page]&.to_i
    end

    def load_previous_page
      redirect_to(root_path(params.permit!.to_h.reverse_merge(page: session.delete(:previous_page)))) && return
    end
  end
end
