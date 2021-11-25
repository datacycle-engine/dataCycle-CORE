# frozen_string_literal: true

module DataCycleCore
  class ReportsController < ApplicationController
    before_action :authenticate_user! # from devise (authenticate)
    authorize_resource class: false # from cancancan (authorize)

    def index
      @reports = DataCycleCore::Feature::ReportGenerator.global_reports
    end

    def download_report
      type = permitted_params[:type]
      identifier = permitted_params[:identifier]
      params = {}
      params[:thing_id] = permitted_params[:thing_id] if permitted_params[:thing_id]
      report_class = DataCycleCore::Feature::ReportGenerator.by_identifier(identifier)
      # begin
      data, options = report_class.constantize.new(params: params, locale: helpers.active_ui_locale).send("to_#{type}")
      send_data data, options
      # rescue
      #   # @todo: add new exception type
      #   raise ArgumentError
      # end
    end

    private

    def permitted_params
      @permitted_params ||= params.permit(*permitted_parameter_keys).reject { |_, v| v.blank? }
    end

    def permitted_parameter_keys
      [:type, :identifier, :thing_id]
    end
  end
end
