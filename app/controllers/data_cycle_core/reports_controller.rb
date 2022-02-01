# frozen_string_literal: true

module DataCycleCore
  class ReportsController < ApplicationController
    before_action :authenticate_user!
    authorize_resource class: false # from cancancan (authorize)

    def index
      @reports = DataCycleCore::Feature::ReportGenerator.global_reports
    end

    def download_report
      params = {}
      if permitted_params[:thing_id]
        thing = DataCycleCore::Thing.find(permitted_params[:thing_id])
        authorize! :download_content_report, thing
        params[:thing_id] = permitted_params[:thing_id]
      else
        authorize! :download_global_report, :report
      end
      params[:key] = permitted_params[:identifier]
      params.merge!(permitted_params[:additional_params].to_h.symbolize_keys) if permitted_params.dig(:additional_params).present?
      report_class = DataCycleCore::Feature::ReportGenerator.by_identifier(permitted_params[:identifier], thing)
      begin
        data, options = report_class.constantize.new(params: params, locale: helpers.active_ui_locale).send("to_#{permitted_params[:type]}")
        send_data data, options
      rescue StandardError => e
        raise DataCycleCore::Error::Report::ProcessingError, e
      end
    end

    private

    def permitted_params
      @permitted_params ||= params.permit(*permitted_parameter_keys).reject { |_, v| v.blank? }
    end

    def permitted_parameter_keys
      [:type, :identifier, :thing_id, additional_params: {}]
    end
  end
end
