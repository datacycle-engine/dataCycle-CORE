module DataCycleCore
  module Api
    module V1
      class ApiBaseController < ActionController::API
        include ActionController::Caching
        include ActionView::Rendering
        include CanCan::ControllerAdditions
        include DataCycleCore::Conversions

        unless Rails.env.development?
          include ActiveSupport::Rescuable
          rescue_from CanCan::AccessDenied, with: :access_denied
          rescue_from ActiveRecord::RecordNotFound, with: :not_found
        end

        DEFAULT_PAGE_SIZE = 25

        before_action :authenticate, :set_default_response_format

        def permitted_params
          params.permit(*permitted_parameter_keys).reject { |_, v| v.blank? }
        end

        def permitted_parameter_keys
          [:format, :page, :per, :token]
        end

        def apply_paging(query)
          query.page(permitted_params.fetch(:page, 1).to_i).per(permitted_params.fetch(:per, DEFAULT_PAGE_SIZE).to_i)
        end

        def tokens
          DataCycleCore.access_tokens
        end

        private

        def authenticate
          return if current_user

          user = User.find_by(access_token: params[:token]) if params[:token].present?

          if user
            sign_in user
          else
            raise CanCan::AccessDenied, 'invalid or missing authentication token'
          end

          # raise CanCan::AccessDenied, 'invalid or missing authentication token' if !tokens.include?(permitted_params[:token]) && current_user.nil?
        end

        def access_denied(exception)
          render status: :access_denied, json: { "error": exception.message }
        end

        def not_found(exception)
          render status: :not_found, json: { "error": exception.message }
        end

        def set_default_response_format
          request.format = :json unless permitted_params[:format]
        end
      end
    end
  end
end
