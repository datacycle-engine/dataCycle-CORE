module DataCycleCore
  class Api::V1::ContentsController < Api::V1::ApiBaseController
    @@default_per = 50

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

      @per = params[:per] unless params[:per].blank?
      @per ||= @@default_per

      @total = deleted_contents.count
      pages = @total.fdiv(@per.to_i).ceil

      unless params[:page].blank?
        @page = params[:page]
        @page = pages if params[:page].to_i > pages
      end
      @page ||= 1

      @contents = deleted_contents.page(@page).per(@per)
    end

    def params
      super.permit(*permitted_parameter_keys).reject { |_, v| v.blank? }
    end

    def permitted_parameter_keys
      [:id, :format, :type, :page, :per, :language, :search, :token, :modified_since, :created_since, :deleted_since]
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

    def apply_paging(query)
      query
        .page([params.fetch(:page, 1).to_i, (query.count / params.fetch(:per, @@default_per).to_i).ceil].min)
        .per(params.fetch(:per, @@default_per).to_i)
    end
  end
end
