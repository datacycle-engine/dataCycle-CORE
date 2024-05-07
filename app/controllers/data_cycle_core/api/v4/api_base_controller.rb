# frozen_string_literal: true

module DataCycleCore
  module Api
    module V4
      class ApiBaseController < ActionController::API
        include ActionController::MimeResponds
        include ActionController::Caching
        include ActionController::RequestForgeryProtection
        include ActionView::Rendering
        include CanCan::ControllerAdditions
        include ActiveSupport::Rescuable
        include DataCycleCore::ErrorHandler
        include DataCycleCore::ApiService
        include DataCycleCore::ApiBeforeActions
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
        before_action :set_default_response_format

        def permitted_params
          return @permitted_params if defined? @permitted_params

          permitted = params.permit(*permitted_parameter_keys)
          validate_api_params(permitted.to_h, validate_params_exceptions)
          @permitted_params = permitted
        end

        def permitted_parameter_keys
          [:api_subversion, :token, :include, :fields, :language, :content_id, :sort, :format, section: {}, page: {}, content_id: [], 'dc:liveData': [], classification_trees: []]
        end

        def validate_params_exceptions
          [:'dc:liveData']
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

          depth = @include_parameters&.map(&:size)&.max
          query.instance_variable_set(:@_recursive_preload_depth, 1 + depth) if depth

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
          current_user.log_activity(type: "api_v#{@api_version}", data: permitted_params.to_h.merge(
            controller: params.dig('controller'),
            action: params.dig('action'),
            format: request.format.to_sym,
            referer: request.referer,
            origin: request.origin,
            middlewareOrigin: request.headers['X-Dc-Middleware-Origin']
          ))
        end

        def prepare_url_parameters
          @url_parameters = permitted_params.except('format')
          @include_parameters = parse_tree_params(permitted_params.dig(:include))
          @fields_parameters = parse_tree_params(permitted_params.dig(:fields))
          @field_filter = @fields_parameters.present?
          @classification_trees_parameters = Array.wrap(permitted_params.dig(:classification_trees))
          @classification_trees_filter = @classification_trees_parameters.present?
          @live_data = permitted_params.dig(:'dc:liveData')
          @section_parameters = section_parameters
          @language = parse_language(permitted_params.dig(:language)).presence || Array(I18n.available_locales.first.to_s)
          @expand_language = false # TODO: language_mode = 'expanded' --> true, 'compact' --> false
          @api_subversion = permitted_params.dig(:api_subversion) if DataCycleCore.main_config.dig(:api, :v4, :subversions)&.include?(permitted_params.dig(:api_subversion))
          @full_text_search = permitted_params.dig(:filter, :search) || permitted_params.dig(:filter, :q)
          @api_version = 4
        end

        private

        def set_default_response_format
          return request.format = :geojson if request.format.geojson? || permitted_params[:format].to_s == 'geojson' || Mime::Type.parse(request.accept.to_s)&.include?(:geojson)

          request.format = :json unless permitted_params[:format]
        end
      end
    end
  end
end
