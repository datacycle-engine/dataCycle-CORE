module DataCycleCore
  class Api::V1::ContentsController < Api::V1::ApiBaseController
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
      query = build_search_query
      query = query.where(content_data_type: content_data_type) if content_data_type
      query = query.modified_since(params[:modified_since]) if params[:modified_since]
      query = query.created_since(params[:created_since]) if params[:created_since]
      query = query.in_validity_period if params[:modified_since] && params[:created_since]
      query = query.fulltext_search(params[:search]) if params[:search]
      query = apply_ordering(query)

      @total = query.count

      @contents = apply_paging(query).map(&:content_data)
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

      @contents = apply_paging(deleted_contents)
    end

    def permitted_parameter_keys
      super + [:id, :format, :type, :language, :search, :modified_since, :created_since, :deleted_since]
    end

    private

    def build_search_query
      query = DataCycleCore::Filter::Search.new(params.fetch(:language, 'de'))
      query
    end

    def content_data_type
      return unless params[:type]
      object_type = DataCycleCore.content_tables.find { |object| object == params[:type] }
      ('DataCycleCore::' + object_type.singularize.classify).constantize
    end

    def apply_ordering(query)
      if params[:search].blank?
        query
      else
        query.order(DataCycleCore::Filter::ObjectBrowserQueryBuilder.get_order_by_query_string(params[:search]))
      end
    end
  end
end
