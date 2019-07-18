# frozen_string_literal: true

module DataCycleCore
  module Api
    module V4
      class ApiBaseController < ::DataCycleCore::Api::V2::ApiBaseController
        def permitted_parameter_keys
          [:api_subversion, :token, :content_id, { page: [:size, :number, :offset, :limit], include: [] }]
        end
      end
    end
  end
end
