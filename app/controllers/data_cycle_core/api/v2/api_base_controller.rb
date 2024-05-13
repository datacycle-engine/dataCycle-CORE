# frozen_string_literal: true

module DataCycleCore
  module Api
    module V2
      class ApiBaseController < ActionController::API
        include ActionController::MimeResponds
        include ActionController::Caching
        include ActionView::Rendering
        include CanCan::ControllerAdditions
        include ActiveSupport::Rescuable
        include DataCycleCore::ErrorHandler
        include DataCycleCore::ApiBeforeActions
        helper DataCycleCore::ApiHelper

        DEFAULT_PAGE_SETTINGS = {
          size: 25,
          number: 1,
          limit: 0,
          offset: 0
        }.freeze

        after_action :log_activity
        before_action :set_default_response_format

        def permitted_params
          @permitted_params ||= params.permit(*permitted_parameter_keys).reject { |_, v| v.blank? }
        end

        def permitted_parameter_keys
          [:api_subversion, :format, :token, { page: [:size, :number, :offset, :limit] }]
        end

        def apply_paging(query)
          page_params = DEFAULT_PAGE_SETTINGS.merge(permitted_params[:page].to_h.reject { |_, v| v.blank? }.symbolize_keys)
          raise DataCycleCore::Error::Api::InvalidArgumentError, "Invalid value for param page[size]: #{page_params[:size]}" unless page_params[:size].to_i.positive?
          query.page(page_params[:number].to_i).per(page_params[:size].to_i)
        end

        def current_ability
          @current_ability ||= (current_user ? DataCycleCore::Ability.new(current_user, session) : nil)
        end

        def log_activity
          current_user.log_activity(type: "api_v#{@api_version}", data: permitted_params.to_h.merge(
            ontroller: params.dig('controller'),
            action: params.dig('action'),
            referer: request.referer,
            origin: request.origin,
            middlewareOrigin: request.headers['X-Dc-Middleware-Origin']
          ))
        end

        private

        def set_default_response_format
          request.format = :json unless permitted_params[:format]
        end
      end
    end
  end
end
