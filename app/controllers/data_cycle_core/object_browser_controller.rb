# frozen_string_literal: true

module DataCycleCore
  class ObjectBrowserController < ApplicationController
    before_action :authenticate_user! # from devise (authenticate)

    DEFAULT_PER = 50

    def show
      authorize! :show, :object_browser
      I18n.with_locale(params[:locale] || I18n.locale) do
        @language = params.fetch(:locale, current_user.default_locale)

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

        order_string = DataCycleCore::Filter::Search.get_order_by_query_string(params[:search])

        query = query.in_validity_period
        query = query.fulltext_search(params[:search]) if params[:search].present?
        query = query.where('content_data_id NOT IN (?)', params[:excluded]) if params[:excluded].present?

        query = query.classification_alias_ids([helpers.life_cycle_items&.dig(DataCycleCore.features&.dig(:life_cycle, :default_filter), :alias)&.id]) if DataCycleCore.features&.dig(:life_cycle, :default_filter).present? && params.dig(:definition, 'linked_table') == 'creative_works'

        query = query.order(order_string)

        @per = params[:per] if params[:per].present?
        @per ||= DEFAULT_PER

        @total = query.count
        @pages = @total.fdiv(@per.to_i).ceil

        if params[:page].present?
          @page = params[:page]
          @page = @pages if params[:page].to_i > @pages
        end
        @page ||= 1

        @results = query.page(@page).per(@per).includes(content_data: [:translations]).map(&:content_data)

        respond_to(:js)
      end
    end

    def find
      authorize! :show, :object_browser
      return if params[:class].blank? || params[:ids].blank?

      I18n.with_locale(params[:locale] || I18n.locale) do
        # TODO: FIXME if breaks
        object_type = DataCycleCore.content_tables.map { |object| ('DataCycleCore::' + object.singularize.classify) }.find { |object| object == params[:class].classify }
        if params[:external]
          @objects = object_type.constantize.where(external_key: params[:ids])
        else
          @objects = object_type.constantize.where(id: params[:ids])
        end
      end

      respond_to(:js)
    end

    def details
      authorize! :show, :object_browser

      unless params[:class].blank? || params[:id].blank?
        I18n.with_locale(params[:locale] || I18n.locale) do
          # TODO: FIXME if breaks
          object_type = DataCycleCore.content_tables.map { |object| ('DataCycleCore::' + object.singularize.classify) }.find { |object| object == params[:class].classify }
          @object = object_type.constantize.find(params[:id])
        end
      end

      respond_to(:js)
    end

    def permitted_params
      params.permit(*permitted_parameter_keys).reject { |_, v| v.blank? }
    end

    def permitted_parameter_keys
      [:class, :per, :page, :id, :locale, :external, :ids, :search, { definition: {} }]
    end

    private

    def data_cycle_object(object_string)
      object_type = DataCycleCore.content_tables.find { |object| object == object_string }
      ('DataCycleCore::' + object_type.singularize.classify).constantize
    end

    #
    # def get_classification_aliases_for_type(type)
    #   if type == 'image'
    #     get_content_classification_aliases('Bild', 'Inhaltstypen')
    #   elsif type == 'video'
    #     get_content_classification_aliases('Video', 'Inhaltstypen')
    #   else
    #     {}
    #   end
    # end
    #
    # def get_content_classification_aliases(labels, tree_label)
    #   DataCycleCore::ClassificationAlias.joins(
    #     :classification_tree_label
    #   ).where(
    #     classification_trees: {
    #       classification_tree_label: DataCycleCore::ClassificationTreeLabel.find_by(name: tree_label)
    #     },
    #     name: [labels]
    #   )
    # end
  end
end
