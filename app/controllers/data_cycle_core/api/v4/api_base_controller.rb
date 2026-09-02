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

        VALIDATE_PARAMS_CONTRACT = nil

        after_action :log_activity, unless: -> { params[:sl] }
        before_action :set_default_response_format

        def permitted_params
          return @permitted_params if defined? @permitted_params

          permitted = params.permit(*permitted_parameter_keys)
          validate_api_params(permitted.to_h, validate_params_exceptions, self.class::VALIDATE_PARAMS_CONTRACT)
          @permitted_params = permitted
        end

        def permitted_parameter_keys
          [:api_subversion, :token, :include, :fields, :language, :content_id, :sort, :format, :classification_trees, :classificationTrees, { section: {}, page: {}, content_id: [], 'dc:liveData': [], classification_trees: [], classificationTrees: [] }]
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
            query = if section_params[:meta].to_i.zero?
                      query.page(page_params[:number].to_i).per(page_params[:size].to_i).without_count
                    else
                      query.page(page_params[:number].to_i).per(page_params[:size].to_i)
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
          current_user.log_request_activity(
            type: "api_v#{@api_version}",
            data: permitted_params.to_h,
            request:,
            activitiable: @collection || @content
          )
        end

        def prepare_url_parameters
          @url_parameters = permitted_params.except('format')
          @include_parameters = parse_tree_params(permitted_params[:include])
          @fields_parameters = parse_tree_params(permitted_params[:fields])
          @field_filter = @fields_parameters.present?
          @classification_trees_parameters = (Array.wrap(permitted_params[:classification_trees]) + Array.wrap(permitted_params[:classificationTrees])).flat_map { |ct| ct.split(',') }.map(&:strip).uniq
          @classification_trees_filter = @classification_trees_parameters.present?
          @live_data = permitted_params[:'dc:liveData']
          @section_parameters = section_parameters
          @language = parse_language(permitted_params[:language]).presence || Array(I18n.default_locale.to_s)
          @expand_language = false # TODO: language_mode = 'expanded' --> true, 'compact' --> false
          @api_subversion = permitted_params[:api_subversion] if DataCycleCore.main_config.dig(:api, :v4, :subversions)&.include?(permitted_params[:api_subversion])
          @full_text_search = permitted_params.dig(:filter, :search) || permitted_params.dig(:filter, :q)
          @api_version = 4
        end

        private

        # Enforce the caller's api-scope visibility (StoredFilter user filters) on a single content fetched
        # by id (DC-14).
        # @param content [DataCycleCore::Thing] the content to check
        # @param skip_validity [Boolean] see #api_scope_query
        def authorize_api_content!(content, skip_validity: false)
          scope_query = api_scope_query(skip_validity:)
          return if scope_query.nil?

          raise CanCan::AccessDenied unless scope_query.exists?(id: content.id)
        end

        # The things the caller may see according to their api-scope user filters, or nil when none applies
        # to them: apply_user_filter then leaves the query unscoped, so every content passes and building
        # the query would only cost a query (DC-14).
        #
        # Memoized per mode, so the check for a content and a restriction of related records (e.g. the
        # duplicate candidates of a content) share one relation and one set of rules.
        # @param skip_validity [Boolean] see #build_api_scope_query
        # @return [ActiveRecord::Relation, nil]
        def api_scope_query(skip_validity: false)
          @api_scope_query ||= {}
          return @api_scope_query[skip_validity] if @api_scope_query.key?(skip_validity)

          @api_scope_query[skip_validity] = build_api_scope_query(skip_validity)
        end

        # +skip_validity+ lets the query reach expired contents, which the endpoints of an internal tool
        # need. It is switched off at the filter methods instead of through parameters or a constructor
        # flag, because a scope resolves nested StoredFilters of its own (+filter_ids+, +union+) that no
        # outer flag reaches. The access scope itself (tenant, pools, shares) applies unchanged.
        # @param skip_validity [Boolean] bypass the validity part of the scope
        def build_api_scope_query(skip_validity)
          scope_filter = DataCycleCore::StoredFilter.new.apply_user_filter(current_user, { scope: 'api' })
          return if scope_filter.user_filter_parameters.blank?
          return scope_filter.things(skip_ordering: true) unless skip_validity

          DataCycleCore::Filter::Common::Date.without_validity_filters do
            scope_filter.things(skip_ordering: true)
          end
        end

        # Renders an error in the shape ErrorHandler#content_api_error produces, for the cases a
        # controller rejects itself instead of raising.
        # @param status [Symbol] http status
        # @param detail [String] human readable reason
        def render_api_error(status, detail)
          render json: { errors: [{ source: { pointer: request.path }, detail: }] }, status:
        end

        def set_default_response_format
          return request.format = :geojson if request.format.geojson? || permitted_params[:format].to_s == 'geojson' || Mime::Type.parse(request.accept.to_s)&.include?(:geojson)

          request.format = :json unless permitted_params[:format]
        end
      end
    end
  end
end
