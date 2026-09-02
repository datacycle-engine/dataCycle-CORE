# frozen_string_literal: true

# simplecov:disable
module DataCycleCore
  module Api
    module V3
      class ApiBaseController < ::DataCycleCore::Api::V2::ApiBaseController
        def permitted_parameter_keys
          [:api_subversion, :format, :token, :content_id, { page: [:size, :number, :offset, :limit] }]
        end
      end
    end
  end
end
# simplecov:enable
