# frozen_string_literal: true

module DataCycleCore
  module Api
    module V2
      class ApiBaseController < ActionController::API
        include ActionController::Caching
        include ActionView::Rendering
        include CanCan::ControllerAdditions
        include DataCycleCore::Common
        helper DataCycleCore::ApiHelper

        unless Rails.env.development?
          include ActiveSupport::Rescuable
          rescue_from CanCan::AccessDenied, with: :access_denied
          rescue_from ActiveRecord::RecordNotFound, with: :not_found
        end

        DEFAULT_PAGE_SETTINGS = {
          size: 25,
          number: 1,
          limit: 0,
          offset: 0
        }.freeze

        before_action :authenticate, :set_default_response_format

        def permitted_params
          @permitted_params ||= params.permit(*permitted_parameter_keys).reject { |_, v| v.blank? }
        end

        def permitted_parameter_keys
          [:format, :token, { page: [:size, :number, :offset, :limit] }]
        end

        def apply_paging(query)
          page_params = DEFAULT_PAGE_SETTINGS.merge(permitted_params[:page].to_h.reject { |_, v| v.blank? }.symbolize_keys)
          query.page(page_params[:number].to_i).per(page_params[:size].to_i)
        end

        def current_ability
          @current_ability ||= DataCycleCore::Ability.new(current_user, session)
        end

        private

        def authenticate
          return if current_user

          user = User.find_by(access_token: params[:token]) if params[:token].present?

          raise CanCan::AccessDenied, 'invalid or missing authentication token' unless user
          sign_in user, store: false
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
