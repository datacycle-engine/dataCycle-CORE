# frozen_string_literal: true

module DataCycleCore
  module Webdav
    module V1
      class WebdavBaseController < ActionController::API
        include ActionController::MimeResponds
        include ActionController::Caching
        include ActionView::Rendering
        include CanCan::ControllerAdditions
        include ActiveSupport::Rescuable
        include DataCycleCore::ErrorHandler
        include DataCycleCore::WebdavHelper
        include DataCycleCore::ApiBeforeActions
        helper DataCycleCore::WebdavHelper

        before_action :set_default_response_format

        def permitted_params
          @permitted_params ||= params.permit(*permitted_parameter_keys).reject { |_, v| v.blank? }
        end

        def permitted_parameter_keys
          [:api_subversion, :format, :id, :file_name, :user_name, :password]
        end

        def log_activity
          current_user.log_activity(type: "api_v#{@api_version}", data: permitted_params.to_h.merge(
            controller: params.dig('controller'),
            action: params.dig('action'),
            referer: request.referer,
            origin: request.origin,
            middlewareOrigin: request.headers['X-Dc-Middleware-Origin']
          ))
        end

        private

        def forbidden(_exception)
          plain_error(:forbidden)
        end

        def access_denied(_exception)
          plain_error(:access_denied)
        end

        def not_found(_exception)
          plain_error(:not_found)
        end

        def bad_request(_exception)
          plain_error(:bad_request)
        end

        def plain_error(status)
          render 'error', status:
        end

        def set_default_response_format
          request.format = :xml
        end
      end
    end
  end
end
