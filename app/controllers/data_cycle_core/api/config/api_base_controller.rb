# frozen_string_literal: true

module DataCycleCore
  module Api
    module Config
      class ApiBaseController < ActionController::API
        include ActionController::MimeResponds
        include ActionController::Caching
        include ActionController::RequestForgeryProtection
        include ActionView::Rendering
        include CanCan::ControllerAdditions
        include ActiveSupport::Rescuable
        include DataCycleCore::ErrorHandler

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

        before_action :set_default_response_format

        def permitted_params
          return @permitted_params if defined? @permitted_params

          permitted = params.permit(*permitted_parameter_keys)
          @permitted_params = permitted
        end

        def permitted_parameter_keys
          [:token, :include, :format, {section: {}, page: {}}]
        end

        def page_parameters
          permitted_params&.dig(:page)&.to_h&.deep_symbolize_keys || {}
        end

        def section_parameters
          permitted_params&.dig(:section)&.to_h&.deep_symbolize_keys || {}
        end

        def apply_paging(_query)
          page_params = DEFAULT_PAGE_SETTINGS.merge(page_parameters)
          DEFAULT_SECTION_SETTINGS.merge(section_parameters)
          raise DataCycleCore::Error::Api::InvalidArgumentError, "Invalid value for param page[size]: #{page_params[:size]}" unless page_params[:size].to_i.positive?
        end

        def current_ability
          @current_ability ||= (current_user ? DataCycleCore::Ability.new(current_user, session) : nil)
        end

        def prepare_url_parameters
          @url_parameters = permitted_params.except('format')
          @section_parameters = section_parameters
        end

        private

        def set_default_response_format
          request.format = :json unless permitted_params[:format]
        end
      end
    end
  end
end
