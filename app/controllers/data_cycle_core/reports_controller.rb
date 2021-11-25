# frozen_string_literal: true

module DataCycleCore
  class ReportsController < ApplicationController
    before_action :authenticate_user! # from devise (authenticate)
    authorize_resource class: false # from cancancan (authorize)

    def index
    end

    def download_report
      # type = permitted_params[:type]
      data, options = DataCycleCore::Report::Downloads.new(params: { limit: 2, by_month: 10 }).to_tsv
      send_data data, options
    end

    private

    def permitted_params
      @permitted_params ||= params.permit(*permitted_parameter_keys).reject { |_, v| v.blank? }
    end

    def permitted_parameter_keys
      [:type]
    end
  end
end
