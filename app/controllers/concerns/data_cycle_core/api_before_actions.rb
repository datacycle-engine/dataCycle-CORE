# frozen_string_literal: true

module DataCycleCore
  module ApiBeforeActions
    extend ActiveSupport::Concern

    included do
      before_action :set_api_version
    end

    private

    def set_api_version
      @api_context = controller_path.match(%r{.*/([a-z_]+)/v\d/.*})&.captures&.first
      @api_version = controller_path.match(%r{.*/v(\d+)/.*})&.captures&.first&.to_i
      @api_subversion = api_version_params[:api_subversion] if DataCycleCore.main_config.dig(:api, :"v#{@api_version}", :subversions)&.include?(api_version_params[:api_subversion])
    end

    def api_version_params
      params.permit(:api_subversion)
    end
  end
end
