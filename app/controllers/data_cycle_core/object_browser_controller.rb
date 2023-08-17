# frozen_string_literal: true

module DataCycleCore
  class ObjectBrowserController < ApplicationController
    DEFAULT_PER = 50

    def show
      authorize! :show, :object_browser
      if permitted_params[:content_id].present?
        @content = DataCycleCore::Thing.find_by(id: permitted_params[:content_id])
      else
        @content = DataCycleCore::Thing.new(template_name: permitted_params[:template_name])
      end

      I18n.with_locale(permitted_params[:locale] || I18n.locale) do
        @definition = permitted_params.dig(:definition)
        template_name = @definition.dig(:template_name)
        stored_filter = @definition.dig(:stored_filter)
        @language = Array(@definition.dig(:linked_language) == 'same' ? permitted_params.fetch(:locale) { current_user.default_locale } : 'all')

        filter = DataCycleCore::StoredFilter.new
          .parameters_from_hash(stored_filter)
          .apply_user_filter(current_user, { scope: 'object_browser', content_template: @content&.template_name, attribute_key: params[:key]&.attribute_name_from_key, template_name: stored_filter.blank? ? template_name : nil })
        filter.language = @language
        filter.parameters.concat Array.wrap(permitted_params.dig(:filter, :f)&.values)

        query = filter.apply
        query = query.where(template_name: template_name.to_s) if template_name && stored_filter.blank?
        query = query.where.not(things: { id: @content.id }) unless @content.nil?
        query = query.where.not(things: { id: permitted_params[:excluded] }) if permitted_params[:excluded].present?
        query = query.where(id: permitted_params[:filter_ids]) if permitted_params[:filter_ids].present?
        filter.parameters&.detect { |f| f['t'] == 'fulltext_search' }&.dig('v')&.then { |s| query = query.sort_fulltext_search('DESC', s) }

        render(json: { count: query.count }) && return if count_only_params[:count_only]

        @per = permitted_params[:per] if permitted_params[:per].present?
        @per ||= DEFAULT_PER

        @page = permitted_params[:page] if permitted_params[:page].present?
        @page ||= 1

        @results = query.content_includes.page(@page).per(@per).without_count

        render json: {
          last_page: @results.last_page?,
          has_contents: !@results.empty?,
          html: render_to_string(formats: [:html], layout: false)
        }
      end
    end

    def find
      authorize! :show, :object_browser
      return if permitted_params[:ids].blank?

      @content = DataCycleCore::Thing.find(permitted_params[:content_id]) if permitted_params[:content_id].present?

      I18n.with_locale(permitted_params[:locale]) do
        if permitted_params[:external]
          @objects = DataCycleCore::Thing.where(external_key: permitted_params[:ids])
        else
          @objects = DataCycleCore::Thing.where(id: permitted_params[:ids])
        end

        render json: { html: render_to_string(formats: [:html], layout: false).strip, ids: @objects.pluck(:id) }
      end
    end

    def render_in_overlay
      authorize! :show, :object_browser

      return if params[:ids].blank?

      @content = DataCycleCore::Thing.find(permitted_params[:content_id]) if permitted_params[:content_id].present?
      @objects = DataCycleCore::Thing.where(id: params[:ids])

      I18n.with_locale(params[:locale]) do
        render json: {
          html: render_to_string('data_cycle_core/contents/create', formats: [:html], layout: false).strip,
          detail_html: render_to_string(formats: [:html], layout: false, action: 'details', locals: { :@object => @objects.first }).strip,
          ids: @objects.pluck(:id)
        }
      end
    end

    def details
      authorize! :show, :object_browser

      I18n.with_locale(permitted_params[:locale]) do
        @object = DataCycleCore::Thing.find(permitted_params[:id])

        render json: { detail_html: render_to_string(formats: [:html], layout: false).strip }
      end
    end

    def permitted_params
      return @permitted_params if defined? @permitted_params

      @permitted_params = DataCycleCore::NormalizeService.normalize_parameters(params.permit(*permitted_parameter_keys))
    end

    def permitted_parameter_keys
      [:per, :page, :id, :locale, :content_id, :template_name, :external, { filter_ids: [] }, { ids: [] }, { definition: {} }, filter: {}, excluded: []]
    end

    def count_only_params
      params.permit(:count_only)
    end
  end
end
