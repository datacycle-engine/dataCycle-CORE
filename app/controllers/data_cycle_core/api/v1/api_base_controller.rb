# frozen_string_literal: true

module DataCycleCore
  module Api
    module V1
      class ApiBaseController < ActionController::API
        include ActionController::MimeResponds
        include ActionController::Caching
        include ActionView::Rendering
        include CanCan::ControllerAdditions
        include ActiveSupport::Rescuable
        include DataCycleCore::ErrorHandler
        include DataCycleCore::ApiBeforeActions

        helper DataCycleCore::ApiHelper

        DEFAULT_PAGE_SIZE = 25

        before_action :set_default_response_format

        def permitted_params
          params.permit(*permitted_parameter_keys).compact_blank
        end

        def permitted_parameter_keys
          [:format, :page, :per, :token]
        end

        def apply_paging(query)
          query.page(permitted_params.fetch(:page, 1).to_i).per(permitted_params.fetch(:per, DEFAULT_PAGE_SIZE).to_i)
        end

        def current_ability
          @current_ability ||= DataCycleCore::Ability.new(current_user, session)
        end

        private

        def set_default_response_format
          request.format = :json unless permitted_params[:format]
        end
      end
    end
  end
end
