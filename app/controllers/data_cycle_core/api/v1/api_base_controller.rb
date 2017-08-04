module DataCycleCore
  class Api::V1::ApiBaseController < ActionController::API
    include ActionView::Rendering
    include CanCan::ControllerAdditions
    ActiveSupport::Rescuable


    # rescue_from CanCan::AccessDenied, with: :access_denied
    # rescue_from ActiveRecord::RecordNotFound, with: :not_found
    before_filter :authenticate

    def tokens
      [
        '85a5c213fa8c27b996edf93159e41274'
      ]
    end


    private

    def authenticate
      if !tokens.include?(params[:token]) && current_user.nil?
        raise CanCan::AccessDenied.new("invalid or missing authentication token")
      end
    end

    def access_denied(exception)
      render status: :access_denied, json: { "error": exception.message }
    end

    def not_found(exception)
      render status: :not_found, json: { "error": exception.message }
    end

  end
end
