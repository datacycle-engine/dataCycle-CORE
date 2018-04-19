module DataCycleCore
  class Api::V1::ContentsController < Api::V1::ApiBaseController
    before_action :index, :prepare_url_parameters

    def show
      object_type = DataCycleCore.content_tables.find { |object| object == permitted_params[:type] }

      unless object_type.nil?
        @content = ('DataCycleCore::' + object_type.singularize.classify).constantize
          .includes({ classifications: [], translations: [] })
          .find(permitted_params[:id])
      end
    end

    def update
      object_type = DataCycleCore.content_tables.find { |object| object == permitted_params[:type] }
      content = permitted_params[:content]

      @content = ('DataCycleCore::' + object_type.singularize.classify).constantize
        .includes({ classifications: [], translations: [] })
        .find(permitted_params[:id])

      render json: @content.get_data_hash
    end

    def destroy
      object_type = DataCycleCore.content_tables.find { |object| object == permitted_params[:type] }

      @content = ('DataCycleCore::' + object_type.singularize.classify).constantize
        .includes({ classifications: [], translations: [] })
        .find(permitted_params[:id])

      # @content.destroy
      # render json: {"success" => @content.destroyed?}
    end

    def search
      query = build_search_query
      query = query.where(content_data_type: content_data_type) if content_data_type
      query = query.modified_since(permitted_params[:modified_since]) if permitted_params[:modified_since]
      query = query.created_since(permitted_params[:created_since]) if permitted_params[:created_since]
      query = query.in_validity_period if permitted_params[:modified_since] && permitted_params[:created_since]
      query = query.fulltext_search(permitted_params[:search]) if permitted_params[:search]
      query = apply_ordering(query)

      @total = query.count

      @contents = apply_paging(query).map(&:content_data)
    end

    def get_deleted
      deleted_contents = DataCycleCore::CreativeWork::History.where(
        DataCycleCore::CreativeWork::History.arel_table[:deleted_at].not_eq(nil)
      )

      @language = permitted_params[:language] unless permitted_params[:language].blank?
      @language ||= 'de'

      if permitted_params[:deleted_since]
        deleted_contents = deleted_contents.where(
          DataCycleCore::CreativeWork::History.arel_table[:deleted_at].gteq(DateTime.parse(permitted_params[:deleted_since]))
        )
      end

      @contents = apply_paging(deleted_contents)
    end

    def permitted_parameter_keys
      super + [:id, :format, :type, :language, :search, :modified_since, :created_since, :deleted_since]
    end

    private

    def prepare_url_parameters
      @url_parameters = permitted_params.reject { |k, _| k == 'format' }
    end

    def build_search_query
      query = DataCycleCore::Filter::Search.new(permitted_params.fetch(:language, 'de'))
      query
    end

    def content_data_type
      return unless permitted_params[:type]
      object_type = DataCycleCore.content_tables.find { |object| object == permitted_params[:type] }
      ('DataCycleCore::' + object_type.singularize.classify).constantize
    end

    def apply_ordering(query)
      if permitted_params[:search].blank?
        query
      else
        query.order(DataCycleCore::Filter::ObjectBrowserQueryBuilder.get_order_by_query_string(permitted_params[:search]))
      end
    end
  end
end
