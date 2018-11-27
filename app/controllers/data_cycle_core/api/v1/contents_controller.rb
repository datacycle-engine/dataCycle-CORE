# frozen_string_literal: true

module DataCycleCore
  module Api
    module V1
      class ContentsController < Api::V1::ApiBaseController
        before_action :prepare_url_parameters, only: :index

        def index
        end

        def show
          object_type = DataCycleCore.content_tables.find { |object| object == permitted_params[:type] }

          return if object_type.nil?
          @content = ('DataCycleCore::' + object_type.singularize.classify).constantize
            .includes({ classifications: [], translations: [] })
            .find(permitted_params[:id])
        end

        def update
          object_type = DataCycleCore.content_tables.find { |object| object == permitted_params[:type] }

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
          query = query.where("searches.content_data_type = 'DataCycleCore::Thing'")
          query = query.modified_since(permitted_params[:modified_since]) if permitted_params[:modified_since]
          query = query.created_since(permitted_params[:created_since]) if permitted_params[:created_since]
          query = query.in_validity_period if permitted_params[:modified_since] && permitted_params[:created_since]
          query = query.fulltext_search(permitted_params[:search]) if permitted_params[:search]
          query = apply_ordering(query)

          @total = query.count

          @contents = apply_paging(query)
        end

        def deleted
          deleted_contents = DataCycleCore::Thing::History.where(
            DataCycleCore::Thing::History.arel_table[:deleted_at].not_eq(nil)
          )

          @language = permitted_params.fetch(:language, current_user.default_locale)

          if permitted_params[:deleted_since]
            deleted_contents = deleted_contents.where(
              DataCycleCore::Thing::History.arel_table[:deleted_at].gteq(Time.zone.parse(permitted_params[:deleted_since]))
            )
          end

          @contents = apply_paging(deleted_contents)
        end

        def permitted_parameter_keys
          super + [:id, :format, :type, :language, :search, :modified_since, :created_since, :deleted_since]
        end

        private

        def build_search_query
          query = DataCycleCore::Filter::Search.new(permitted_params.fetch(:language, 'de'))
          query
        end

        def prepare_url_parameters
          @url_parameters = permitted_params.reject { |k, _| k == 'format' }
        end

        def apply_ordering(query)
          if permitted_params[:search].blank?
            query
          else
            query.order(DataCycleCore::Filter::Search.get_order_by_query_string(permitted_params[:search]))
          end
        end
      end
    end
  end
end
