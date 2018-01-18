module DataCycleCore
  class Api::V1::ContentsController < Api::V1::ApiBaseController
    @default_per = 50

    def show
      object_type = DataCycleCore.content_tables.find { |object| object == params[:type] }

      unless object_type.nil?
        @content = ('DataCycleCore::' + object_type.singularize.classify).constantize
          .includes({ classifications: [], translations: [] })
          .find(params[:id])
      end
    end

    def update
      object_type = DataCycleCore.content_tables.find { |object| object == params[:type] }
      content = params[:content]

      @content = ('DataCycleCore::' + object_type.singularize.classify).constantize
        .includes({ classifications: [], translations: [] })
        .find(params[:id])

      render json: @content.get_data_hash
    end

    def destroy
      object_type = DataCycleCore.content_tables.find { |object| object == params[:type] }

      @content = ('DataCycleCore::' + object_type.singularize.classify).constantize
        .includes({ classifications: [], translations: [] })
        .find(params[:id])

      # @content.destroy
      # render json: {"success" => @content.destroyed?}
    end

    def search
      @language = params[:language] unless params[:language].blank?
      @language ||= 'de'

      order_string = DataCycleCore::Filter::ObjectBrowserQueryBuilder.get_order_by_query_string(params[:search])

      classification_aliases = DataCycleCore::ClassificationAlias.joins(
        :classification_tree_label
      ).where(
        classification_trees: {
          classification_tree_label: DataCycleCore::ClassificationTreeLabel.find_by(name: 'Inhaltstypen')
        }
      )

      classification_aliases = classification_aliases.where(name: DataCycleCore.allowed_content_api_classifications) unless DataCycleCore.allowed_content_api_classifications.blank?

      query = DataCycleCore::Filter::Search.new(@language).where(content_data_type: DataCycleCore::CreativeWork)
      query = query.with_classification_alias_ids(classification_aliases.map(&:id))
      query = query.fulltext_search(params[:search]) unless params[:search].blank?

      query = query.modified_since(params[:modified_since]) if params[:modified_since]

      query = query.created_since(params[:created_since]) if params[:created_since]

      query = query.in_validity_period if params[:modified_since].blank? && params[:created_since].blank?

      query = query.order(order_string)

      @per = params[:per] unless params[:per].blank?
      @per ||= @default_per

      @total = query.count
      pages = @total.fdiv(@per.to_i).ceil

      unless params[:page].blank?
        @page = params[:page]
        @page = pages if params[:page].to_i > pages
      end
      @page ||= 1

      @contents = query.page(@page).per(@per).map(&:content_data)
    end

    def get_deleted
      deleted_contents = DataCycleCore::CreativeWork::History.where(
        DataCycleCore::CreativeWork::History.arel_table[:deleted_at].not_eq(nil)
      )

      @language = params[:language] unless params[:language].blank?
      @language ||= 'de'

      if params[:deleted_since]
        deleted_contents = deleted_contents.where(
          DataCycleCore::CreativeWork::History.arel_table[:deleted_at].gteq(DateTime.parse(params[:deleted_since]))
        )
      end

      @per = params[:per] unless params[:per].blank?
      @per ||= @default_per

      @total = deleted_contents.count
      pages = @total.fdiv(@per.to_i).ceil

      unless params[:page].blank?
        @page = params[:page]
        @page = pages if params[:page].to_i > pages
      end
      @page ||= 1

      @contents = deleted_contents.page(@page).per(@per)
    end

    private

    def content_params
      params.permit(:page, :per, :language, :search, :token, :modified_since, :created_since, :deleted_since)
    end

    def build_search_query
      query = DataCycleCore::Filter::Search.new(content_params.fetch(:language, 'de'))
      query
    end

    def content_data_type
      Object.const_get("DataCycleCore::#{content_params[:type].classify}") if content_params[:type]
    end

    def apply_ordering(query)
      if content_params[:search].blank?
        query
      else
        query.order(DataCycleCore::Filter::ObjectBrowserQueryBuilder.get_order_by_query_string(content_params[:search]))
      end
    end

    def apply_paging(query)
      query
        .page([content_params.fetch(:page, 1).to_i, (query.count / content_params.fetch(:per, @default_per).to_i).ceil].min)
        .per(content_params.fetch(:per, @default_per).to_i)
    end
  end
end
