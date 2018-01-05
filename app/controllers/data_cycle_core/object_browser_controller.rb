module DataCycleCore
  class ObjectBrowserController < ApplicationController
    before_action :authenticate_user!   # from devise (authenticate)
    load_and_authorize_resource :class => false, except: :find         # from cancancan (authorize)

    def show
      I18n.with_locale(params[:language] || I18n.locale) do
        @language = params[:language] unless params[:language].blank?
        @language ||= "de"

        @@default_per = 50

        @type = params[:type] unless params[:type].blank?
        @type ||= "image"

        order_string = DataCycleCore::Filter::ObjectBrowserQueryBuilder::get_order_by_query_string(params[:search])

        query = DataCycleCore::Filter::ObjectBrowserQueryBuilder.new(@language, @type)
        query = query.fulltext_search(params[:search]) unless params[:search].blank?
        query = query.with_classification_alias_ids(get_classification_aliases_for_type(@type).map(&:id)) unless get_classification_aliases_for_type(@type).blank?
        query = query.order(order_string)

        @per = params[:per] unless params[:per].blank?
        @per ||= @@default_per

        total = query.count
        pages = total.fdiv(@per.to_i).ceil

        unless params[:page].blank?
          @page = params[:page]
          @page = pages if params[:page].to_i > pages
        end
        @page ||= 1

        @results = query.page(@page).per(@per).includes(content_data: [:translations]).map(&:content_data)
        render :json => { results: @results.as_json({'add_validity' => true }), total: total }
      end
    end

    def find
      authorize! :show, :object_browser
      if !params[:class].blank? && !params[:ids].blank?
        object = params[:class].constantize
        result = object.where(id: params[:ids])

        render :json => result
      end
    end

    private

    def get_classification_aliases_for_type(type)
      case
        when type == 'image'
          get_content_classification_aliases('Bild','Inhaltstypen')
        when type == 'video'
          get_content_classification_aliases('Video','Inhaltstypen')
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
