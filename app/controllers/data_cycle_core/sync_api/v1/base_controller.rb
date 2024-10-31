# frozen_string_literal: true

module DataCycleCore
  module SyncApi
    module V1
      class BaseController < ActionController::API
        include ActionController::MimeResponds
        include ActionController::Caching
        include ActionView::Rendering
        include CanCan::ControllerAdditions
        include ActiveSupport::Rescuable
        include DataCycleCore::ErrorHandler
        include DataCycleCore::ApiBeforeActions
        include DryParams

        wrap_parameters format: []

        DEFAULT_PAGE_SETTINGS = {
          size: 25,
          number: 1,
          limit: 0,
          offset: 0
        }.freeze

        after_action :log_activity, unless: -> { params[:sl] }
        before_action :set_default_response_format

        def permitted_params
          @permitted_params ||= params.permit(*permitted_parameter_keys)
        end

        def permitted_parameter_keys
          [:api_subversion, :token, {page: {}}]
        end

        def page_parameters
          permitted_params&.dig(:page)&.to_h&.deep_symbolize_keys || {}
        end

        def parse_language(language_string)
          return nil if language_string&.strip.blank?
          language_string.split(',')&.map(&:strip)&.select { |t| I18n.available_locales.include?(t.to_sym) }
        end

        def apply_paging(query)
          page_params = DEFAULT_PAGE_SETTINGS.merge(page_parameters)
          raise DataCycleCore::Error::Api::InvalidArgumentError, "Invalid value for param page[size]: #{page_params[:size]}" unless page_params[:size].to_i.positive?
          query.page(page_params[:number].to_i).per(page_params[:size].to_i)
        end

        def current_ability
          @current_ability ||= (current_user ? DataCycleCore::Ability.new(current_user, session) : nil)
        end

        def log_activity
          current_user.log_request_activity(
            type: "sync_api_v#{@sync_api_version}",
            data: permitted_params.to_h,
            request:,
            activitiable: @collection || @content
          )
        end

        def prepare_url_parameters
          @url_parameters = permitted_params.except('format')
          @language = parse_language(permitted_params[:language]).presence || Array(I18n.available_locales.first.to_s)
          @api_subversion = permitted_params[:api_subversion] if DataCycleCore.main_config.dig(:sync_api, :v4, :subversions)&.include?(permitted_params[:api_subversion])
          @full_text_search = permitted_params.dig(:filter, :search) || permitted_params.dig(:filter, :q)
          @updated_since = permitted_params[:updated_since]&.try(:in_time_zone)
          @api_version = 1
        end

        private

        def set_default_response_format
          request.format = :json unless permitted_params[:format]
        end
      end
    end
  end
end
