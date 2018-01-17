module DataCycleCore
  class ObjectBrowserController < ApplicationController
    before_action :authenticate_user! # from devise (authenticate)

    def show
      authorize! :show, :object_browser
      I18n.with_locale(params[:language] || I18n.locale) do
        @language = params[:language] unless params[:language].blank?
        @language ||= "de"

        @@default_per = 50

        @type = params[:type] unless params[:type].blank?
        @type ||= "image"

        order_string = DataCycleCore::Filter::ObjectBrowserQueryBuilder.get_order_by_query_string(params[:search])

        query = DataCycleCore::Filter::ObjectBrowserQueryBuilder.new(@language, @type)
        query = query.fulltext_search(params[:search]) unless params[:search].blank?
        query = query.with_classification_alias_ids(get_classification_aliases_for_type(@type).map(&:id)) unless get_classification_aliases_for_type(@type).blank?
        query = query.order(order_string)

        @per = params[:per] unless params[:per].blank?
        @per ||= @@default_per

        @total = query.count
        @pages = @total.fdiv(@per.to_i).ceil

        unless params[:page].blank?
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
      if !params[:class].blank? && !params[:ids].blank?

        I18n.with_locale(params[:language] || I18n.locale) do
          # TODO: FIXME if breaks
          object_type = DataCycleCore.content_tables.map { |object| ('DataCycleCore::' + object.singularize.classify) }.find { |object| object == params[:class].classify }
          @objects = object_type.constantize.where(id: params[:ids])
        end

        respond_to(:js)
      end
    end

    def details
      authorize! :show, :object_browser

      unless params[:class].blank? || params[:id].blank?
        I18n.with_locale(params[:language] || I18n.locale) do
          # TODO: FIXME if breaks
          object_type = DataCycleCore.content_tables.map { |object| ('DataCycleCore::' + object.singularize.classify) }.find { |object| object == params[:class].classify }
          @object = object_type.constantize.find(params[:id])
        end
      end

      respond_to(:js)
    end

    private

    def get_classification_aliases_for_type(type)
      if type == 'image'
        get_content_classification_aliases('Bild', 'Inhaltstypen')
      elsif type == 'video'
        get_content_classification_aliases('Video', 'Inhaltstypen')
      else
        {}
      end
    end

    def get_content_classification_aliases(labels, tree_label)
      DataCycleCore::ClassificationAlias.joins(
        :classification_tree_label
      ).where(
        classification_trees: {
          classification_tree_label: DataCycleCore::ClassificationTreeLabel.find_by(name: tree_label)
        },
        name: [labels]
      )
    end
  end
end
