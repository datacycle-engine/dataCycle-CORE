# frozen_string_literal: true

module DataCycleCore
  module Mvt
    module V1
      class MvtBaseController < ::DataCycleCore::Api::V4::ApiBaseController
        # def permitted_params
        #   @permitted_params ||= params.permit(*permitted_parameter_keys)
        # end

        def prepare_url_parameters
          super
          @api_version = 1
        end

        def log_activity
        end
      end
    end
  end
end
