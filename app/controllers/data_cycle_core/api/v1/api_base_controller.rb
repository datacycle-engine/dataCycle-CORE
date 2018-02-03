module DataCycleCore
  class Api::V1::ApiBaseController < ActionController::API
    include ActionController::Caching
    include ActionView::Rendering
    include CanCan::ControllerAdditions
    # include ActiveSupport::Rescuable
    include DataCycleCore::Conversions

    # rescue_from CanCan::AccessDenied, with: :access_denied
    # rescue_from ActiveRecord::RecordNotFound, with: :not_found

    DEFAULT_PAGE_SIZE = 25

    before_action :authenticate, :set_default_response_format

    def params
      super.permit(*permitted_parameter_keys).reject { |_, v| v.blank? }
    end

    def permitted_parameter_keys
      [:format, :page, :per, :token]
    end

    def apply_paging(query)
      query.page(params.fetch(:page, 1).to_i).per(params.fetch(:per, DEFAULT_PAGE_SIZE).to_i)
    end

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
