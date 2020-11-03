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
        helper DataCycleCore::ApiHelper

        unless Rails.env.development?
          rescue_from ActionController::UnknownFormat, with: :not_acceptable
          rescue_from CanCan::AccessDenied, with: :unauthorized
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

        def current_ability
          @current_ability ||= DataCycleCore::Ability.new(current_user, session)
        end

        private

        def authenticate
          return if current_user

          user = User.find_by(access_token: params[:token]) if params[:token].present?

          raise CanCan::AccessDenied, 'invalid or missing authentication token' unless user
          request.env['devise.skip_trackable'] = true
          sign_in user, store: false
        end

        def set_default_response_format
          request.format = :json unless permitted_params[:format]
        end
      end
    end
  end
end
