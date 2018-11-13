# frozen_string_literal: true

module DataCycleCore
  class ObjectBrowserController < ApplicationController
    before_action :authenticate_user! # from devise (authenticate)

    DEFAULT_PER = 50

    def show
      authorize! :show, :object_browser
      I18n.with_locale(permitted_params[:locale] || I18n.locale) do
        @language = [permitted_params.fetch(:locale, current_user.default_locale)]

        @definition = permitted_params.fetch(:definition, nil)

        filter = DataCycleCore::StoredFilter.new
        filter.language = @language

        linked_table = @definition.fetch(:linked_table, nil)
        template_name = @definition.fetch(:template_name, nil)
        stored_filter = @definition.fetch(:stored_filter, nil)

        if stored_filter.present?
          stored_filter_params = stored_filter.to_a.map(&:to_h).map do |f|
            f.each_with_object({}) do |(k, v), hash|
              hash['t'] = k
              hash['v'] = v
            end
          end
          filter.parameters = stored_filter_params
          query = filter.apply
        else
          query = filter.apply
          query = query.where(content_data_type: data_cycle_object(linked_table).to_s) if data_cycle_object(linked_table)
          query = query.where(data_type: template_name.to_s) if template_name
        end

        order_string = DataCycleCore::Filter::Search.get_order_by_query_string(permitted_params[:search])

        query = query.in_validity_period
        query = query.fulltext_search(permitted_params[:search]) if permitted_params[:search].present?
        query = query.where('content_data_id NOT IN (?)', permitted_params[:excluded]) if permitted_params[:excluded].present?

        unless template_name == 'contentLocation'
          query = query.classification_alias_ids([DataCycleCore::Feature::LifeCycle.ordered_classifications.dig(DataCycleCore::Feature::LifeCycle.default_filter, :alias_id)]) if DataCycleCore::Feature::LifeCycle.enabled? && DataCycleCore::Feature::LifeCycle.default_filter.present? && permitted_params.dig(:definition, 'linked_table') == 'things'
        end

        query = query.order(order_string)

        @per = permitted_params[:per] if permitted_params[:per].present?
        @per ||= DEFAULT_PER

        @total = query.count
        @pages = @total.fdiv(@per.to_i).ceil

        if permitted_params[:page].present?
          @page = permitted_params[:page]
          @page = @pages if permitted_params[:page].to_i > @pages
        end
        @page ||= 1

        @results = query.page(@page).per(@per).includes(content_data: [:translations]).map(&:content_data)

        respond_to(:js)
      end
    end

    def find
      authorize! :show, :object_browser
      return if permitted_params[:class].blank? || permitted_params[:ids].blank?

      I18n.with_locale(permitted_params[:locale] || I18n.locale) do
        if permitted_params[:external]
          @objects = data_cycle_object(permitted_params[:class].demodulize.tableize).where(external_key: permitted_params[:ids])
        else
          @objects = data_cycle_object(permitted_params[:class].demodulize.tableize).where(id: permitted_params[:ids])
        end
      end

      respond_to(:js)
    end

    def details
      authorize! :show, :object_browser

      unless permitted_params[:class].blank? || permitted_params[:id].blank?
        I18n.with_locale(permitted_params[:locale] || I18n.locale) do
          @object = data_cycle_object(permitted_params[:class].demodulize.tableize).find(permitted_params[:id])
        end
      end

      respond_to(:js)
    end

    def permitted_params
      params.permit(*permitted_parameter_keys)
    end

    def permitted_parameter_keys
      [:class, :per, :page, :id, :locale, :external, { ids: [] }, :search, :excluded, { definition: {} }]
    end
  end
end
