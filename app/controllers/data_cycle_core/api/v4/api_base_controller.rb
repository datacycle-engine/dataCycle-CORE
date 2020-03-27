# frozen_string_literal: true

module DataCycleCore
  module Api
    module V4
      class ApiBaseController < ActionController::API
        include ActionController::MimeResponds
        include ActionController::Caching
        include ActionView::Rendering
        include CanCan::ControllerAdditions
        include ActiveSupport::Rescuable
        include DataCycleCore::ErrorHandler
        include ActionController::HttpAuthentication::Token::ControllerMethods
        helper DataCycleCore::ApiHelper

        unless Rails.env.development?
          rescue_from ActionController::UnknownFormat, with: :not_acceptable
          rescue_from CanCan::AccessDenied, with: :unauthorized
          rescue_from ActiveRecord::RecordNotFound, with: :not_found
        end

        DEFAULT_PAGE_SETTINGS = {
          size: 25,
          number: 1,
          limit: 0,
          offset: 0
        }.freeze

        after_action :log_activity
        before_action :authenticate, :set_default_response_format

        def permitted_params
          @permitted_params ||= params.permit(*permitted_parameter_keys).reject { |_, v| v.blank? }
        end

        def permitted_parameter_keys
          [:api_subversion, :token, :include, :fields, :content_id, :mode, { page: [:size, :number, :offset, :limit] }]
        end

        def page_parameters
          permitted_params&.dig(:page)&.to_h&.symbolize_keys&.reject { |k, v| v.blank? || !permitted_page_params&.include?(k) } || {}
        end

        def mode_parameters
          permitted_params&.dig(:mode)
        end

        def permitted_page_params
          [:size, :number, :offset, :limit]
        end

        def apply_paging(query)
          page_params = DEFAULT_PAGE_SETTINGS.merge(page_parameters)
          raise DataCycleCore::Error::Api::InvalidArgumentError, "Invalid value for param page[size]: #{page_params[:size]}" unless page_params[:size].to_i.positive?
          if mode_parameters == 'strict'
            query.page(page_params[:number].to_i).per(page_params[:size].to_i).without_count
          else
            query.page(page_params[:number].to_i).per(page_params[:size].to_i)
          end
        end

        def current_ability
          @current_ability ||= (current_user ? DataCycleCore::Ability.new(current_user, session) : nil)
        end

        def parse_tree_params(raw_params)
          return [] if raw_params&.strip.blank?
          raw_params.split(',')&.map(&:strip)&.map { |item| item.split('.')&.map(&:strip) }
        end

        def parse_language(language_string)
          return nil if language_string&.strip.blank?
          language_string.split(',')&.map(&:strip)&.select { |t| I18n.available_locales.include?(t.to_sym) }
        end

        def log_activity
          activity_data = permitted_params.to_h.merge(controller: params.dig('controller'), action: params.dig('action'))
          current_user.activities.create(activity_type: "api_v#{@api_version}", data: activity_data)
        end

        private

        def request_http_token_authentication(realm = 'Application', _message = nil)
          headers['WWW-Authenticate'] = %(Token realm="#{realm.delete('"')}")
          raise CanCan::AccessDenied, 'HTTP Token: Access denied.'
        end

        def authenticate
          return if current_user

          if request.headers['Authorization'].present?
            authenticate_or_request_with_http_token do |token|
              @decoded = DataCycleCore::JsonWebToken.decode(token)
              @user = DataCycleCore::User.find_with_token(@decoded)
            rescue JWT::DecodeError, JSON::ParserError => e
              raise CanCan::AccessDenied, e.message
            end
          elsif params[:token].present?
            @user = User.find_by(access_token: params[:token])
          end

          raise CanCan::AccessDenied, 'invalid or missing authentication token' if @user.nil?

          sign_in @user, store: false
        end

        def set_default_response_format
          request.format = :json unless permitted_params[:format]
        end
      end
    end
  end
end
