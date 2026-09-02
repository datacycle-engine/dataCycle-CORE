# frozen_string_literal: true

module DataCycleCore
  class ObjectBrowserController < ApplicationController
    DEFAULT_PER = 50

    include DataCycleCore::ContentByIdOrTemplate

    def show
      authorize! :show, :object_browser

      @content = content_by_id_or_template
      @parent = DataCycleCore::Thing.find(permitted_params[:parent_id]) if permitted_params[:parent_id].present?

      I18n.with_locale(permitted_params[:locale] || I18n.locale) do
        @definition = permitted_params[:definition]
        template_names = Array.wrap(@definition[:template_name]).map(&:to_s).compact_blank
        stored_filter = @definition[:stored_filter]
        @language = Array(@definition[:linked_language] == 'same' ? permitted_params.fetch(:locale) { current_user.default_locale } : 'all')

        filter = DataCycleCore::StoredFilter.new
          .parameters_from_hash(stored_filter)
          .apply_user_filter(current_user, {
            scope: 'object_browser',
            content: @content,
            attribute_key: attribute_key_params[:key]&.attribute_name_from_key,
            template_name: stored_filter.blank? ? template_names : nil
          })
        filter.language = @language
        filters = sanitize_request_filters(permitted_params.dig(:filter, :f)&.values)
        filter.parameters.concat(filters)
        filter.apply_sorting_from_parameters(filters: filters, sort_params: Array.wrap(permitted_params.dig(:filter, :s, :v)))

        query = filter.apply
        query = query.where(template_name: template_names) if template_names.present? && stored_filter.blank?
        query = query.where.not(things: { id: @content.id }) unless @content.nil?
        query = query.where.not(things: { id: permitted_params[:excluded] }) if permitted_params[:excluded].present?
        query = query.where(id: permitted_params[:filter_ids]) if permitted_params[:filter_ids].present?

        query = limit_query_to_linked_content(query)

        render(json: { count: query.count }) && return if count_only_params[:count_only]

        @per = permitted_params[:per] if permitted_params[:per].present?
        @per ||= DEFAULT_PER

        @page = permitted_params[:page] if permitted_params[:page].present?
        @page ||= 1

        @results = query.content_includes.page(@page).per(@per).without_count

        render json: {
          last_page: @results.last_page?,
          has_contents: !@results.empty?,
          html: render_to_string(formats: [:html], layout: false, locals: ob_params)
        }
      end
    end

    # Server side counterpart to the DOM based `limited_by`: restricts the object
    # browser results to the contents the content currently being edited is already
    # linked to via one or more attributes, configured per property via
    # `ui.edit.options.limited_by_linked` (a single attribute or a list). The ids
    # are read from the current content's own attribute values - this respects the
    # attribute's link direction and works even for computed attributes that are
    # not rendered in the edit form (unlike the DOM based `limited_by`). A
    # blank/new content has no such links yet, so nothing is offered until it has
    # been saved once.
    #
    # `@definition` is request supplied, so the configured relation names are
    # restricted to the content's actual linked properties before they are read
    # via `try`. Without this whitelist an arbitrary, client-chosen method name
    # would be invoked on the content (e.g. `destroy`), which is unsafe.
    def limit_query_to_linked_content(query)
      relations = Array.wrap(@definition.dig(:ui, :edit, :options, :limited_by_linked)).compact_blank
      return query if relations.blank?

      relations &= Array.wrap(@content&.linked_property_names(true))
      return query.where(id: []) if relations.blank?

      linked_ids = relations.flat_map { |relation| Array.wrap(@content.try(relation)&.pluck(:id)) }.uniq

      query.where(id: linked_ids)
    end

    def find
      authorize! :show, :object_browser
      return if permitted_params[:ids].blank?

      @content = content_by_id_or_template
      @parent = DataCycleCore::Thing.find(permitted_params[:parent_id]) if permitted_params[:parent_id].present?

      I18n.with_locale(permitted_params[:locale]) do
        @objects = if permitted_params[:external]
                     DataCycleCore::Thing.in_order_of(:external_key, permitted_params[:ids])
                   else
                     DataCycleCore::Thing.in_order_of(:id, permitted_params[:ids])
                   end

        render json: { html: render_to_string(formats: [:html], layout: false, locals: ob_params).strip, ids: @objects.pluck(:id) }
      end
    end

    def render_in_overlay
      authorize! :show, :object_browser

      return if params[:ids].blank?

      @content = content_by_id_or_template
      @objects = DataCycleCore::Thing.where(id: params[:ids])

      I18n.with_locale(params[:locale]) do
        render json: {
          html: render_to_string('data_cycle_core/contents/create', formats: [:html], layout: false).strip,
          detail_html: render_to_string(formats: [:html], layout: false, action: 'details', assigns: { object: @objects.first }).strip,
          ids: @objects.pluck(:id)
        }
      end
    end

    def details
      authorize! :show, :object_browser

      I18n.with_locale(permitted_params[:locale]) do
        @object = DataCycleCore::Thing.find(permitted_params[:id])

        render json: { detail_html: render_to_string(formats: [:html], layout: false, locals: ob_params).strip }
      end
    end

    def permitted_params
      return @permitted_params if defined? @permitted_params

      @permitted_params = DataCycleCore::NormalizeService.normalize_parameters(params.permit(*permitted_parameter_keys))
    end

    def permitted_parameter_keys
      [:per, :page, :id, :locale, :external, :parent_id, { filter_ids: [], ids: [], definition: {}, filter: {}, excluded: [] }]
    end

    def attribute_key_params
      params.permit(:key)
    end

    def count_only_params
      params.permit(:count_only)
    end

    def ob_params
      params.permit(:locale, :editable, :key, :prefix, { objects: [] }, { definition: {} }, { options: {} }).to_h
    end
  end
end
