module DataCycleCore
  class Api::V1::ApiBaseController < ActionController::API
    include ActionController::Caching
    include ActionView::Rendering
    include CanCan::ControllerAdditions
    # include ActiveSupport::Rescuable
    include DataCycleCore::Conversions

    # rescue_from CanCan::AccessDenied, with: :access_denied
    # rescue_from ActiveRecord::RecordNotFound, with: :not_found

    before_action :authenticate, :set_default_response_format

    def tokens
      DataCycleCore.access_tokens
    end

    private

    def authenticate
      raise CanCan::AccessDenied, 'invalid or missing authentication token' if !tokens.include?(params[:token]) && current_user.nil?
    end

    def access_denied(exception)
      render status: :access_denied, json: { "error": exception.message }
    end

    def not_found(exception)
      render status: :not_found, json: { "error": exception.message }
    end

    def set_default_response_format
      request.format = :json unless params[:format]
    end
  end
end
