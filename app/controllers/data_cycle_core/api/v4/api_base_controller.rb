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
        include DataCycleCore::ApiService
        helper DataCycleCore::ApiHelper

        wrap_parameters format: []

        DEFAULT_PAGE_SETTINGS = {
          size: 25,
          number: 1,
          limit: 0,
          offset: 0
        }.freeze

        DEFAULT_SECTION_SETTINGS = {
          '@graph': 1,
          '@context': 1,
          meta: 1,
          links: 1
        }.freeze

        after_action :log_activity, unless: -> { params[:sl] }
        before_action :authenticate, :set_default_response_format

        # TODO: move validate_api_params to be called before permitted_params
        def permitted_params
          validate_api_params(params.to_unsafe_hash)
          @permitted_params ||= params.permit(*permitted_parameter_keys)
        end

        def permitted_parameter_keys
          [:api_subversion, :token, :include, :fields, :language, :content_id, :sort, :format, section: {}, page: {}, content_id: [], 'dc:liveData': []]
        end

        def page_parameters
          permitted_params&.dig(:page)&.to_h&.deep_symbolize_keys || {}
        end

        def section_parameters
          permitted_params&.dig(:section)&.to_h&.deep_symbolize_keys || {}
        end

        def apply_paging(query)
          page_params = DEFAULT_PAGE_SETTINGS.merge(page_parameters)
          section_params = DEFAULT_SECTION_SETTINGS.merge(section_parameters)
          raise DataCycleCore::Error::Api::InvalidArgumentError, "Invalid value for param page[size]: #{page_params[:size]}" unless page_params[:size].to_i.positive?
          if page_params[:limit].to_i.positive?
            query = query.offset(page_params[:offset].to_i).limit(page_params[:limit].to_i).query
          else
            if section_params[:meta].to_i.zero?
              query = query.page(page_params[:number].to_i).per(page_params[:size].to_i).without_count
            else
              query = query.page(page_params[:number].to_i).per(page_params[:size].to_i)
            end
            query = query.padding(page_params[:offset].to_i) if page_params[:offset].to_i.positive?
          end
          query
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

        def prepare_url_parameters
          @url_parameters = permitted_params.reject { |k, _| k == 'format' }
          @include_parameters = parse_tree_params(permitted_params.dig(:include))
          @fields_parameters = parse_tree_params(permitted_params.dig(:fields))
          @field_filter = @fields_parameters.present?
          @live_data = permitted_params.dig(:'dc:liveData')
          @section_parameters = section_parameters
          @language = parse_language(permitted_params.dig(:language)).presence || Array(I18n.available_locales.first.to_s)
          @api_subversion = permitted_params.dig(:api_subversion) if DataCycleCore.main_config.dig(:api, :v4, :subversions)&.include?(permitted_params.dig(:api_subversion))
          @full_text_search = permitted_params.dig(:filter, :search) || permitted_params.dig(:filter, :q)
          @api_version = 4
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

          request.env['devise.skip_trackable'] = true
          sign_in @user, store: false
        end

        def set_default_response_format
          request.format = :json unless permitted_params[:format]
        end
      end
    end
  end
end
