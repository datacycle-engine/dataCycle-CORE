module DataCycleCore
  class Api::V1::ApiBaseController < ActionController::API
    ActiveSupport::Rescuable

    TOKEN = "85a5c213fa8c27b996edf93159e41274"

    rescue_from CanCan::AccessDenied, with: :access_denied
    rescue_from ActiveRecord::RecordNotFound, with: :not_found
    before_filter :check_token

    private

    def check_token
      if params[:token].blank? || params[:token] != TOKEN
        raise CanCan::AccessDenied.new("unvalid token given")
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
