# frozen_string_literal: true

module DataCycleCore
  module Api
    module V2
      class ContentsController < Api::V2::ApiBaseController
        before_action :prepare_url_parameters

        def index
          query = build_search_query
          query = query.where(content_data_type: content_data_type.to_s) if content_data_type
          query = query.modified_since(permitted_params[:modified_since]) if permitted_params[:modified_since]
          query = query.created_since(permitted_params[:created_since]) if permitted_params[:created_since]
          query = query.in_validity_period if permitted_params[:modified_since] && permitted_params[:created_since]
          query = query.fulltext_search(permitted_params[:q]) if permitted_params[:q]
          query = apply_ordering(query)

          @pagination_contents = apply_paging(query)
          @contents = @pagination_contents.map(&:content_data)
        end

        def show
          object_type = content_data_type
          return if object_type.nil?
          @content = object_type
            .includes({ classifications: [], translations: [] })
            .find(permitted_params[:id])

          I18n.with_locale(@content.first_available_locale(params.fetch(:language, :de).to_sym)) do
            render 'show'
          end
        end

        # def update
        #   object_type = DataCycleCore.content_tables.find { |object| object == permitted_params[:type] }
        #
        #   @content = ('DataCycleCore::' + object_type.singularize.classify).constantize
        #     .includes({ classifications: [], translations: [] })
        #     .find(permitted_params[:id])
        #
        #   render json: @content.get_data_hash
        # end
        #
        # def destroy
        #   object_type = DataCycleCore.content_tables.find { |object| object == permitted_params[:type] }
        #
        #   @content = ('DataCycleCore::' + object_type.singularize.classify).constantize
        #     .includes({ classifications: [], translations: [] })
        #     .find(permitted_params[:id])
        #
        #   # @content.destroy
        #   # render json: {"success" => @content.destroyed?}
        # end

        def search
          index
        end

        # TODO: refactor
        def deleted
          deleted_contents = DataCycleCore::CreativeWork::History.where(
            DataCycleCore::CreativeWork::History.arel_table[:deleted_at].not_eq(nil)
          )

          @language = permitted_params[:language] if permitted_params[:language].present?
          @language ||= 'de'

          if permitted_params[:deleted_since]
            deleted_contents = deleted_contents.where(
              DataCycleCore::CreativeWork::History.arel_table[:deleted_at].gteq(Time.zone.parse(permitted_params[:deleted_since]))
            )
          end

          @contents = apply_paging(deleted_contents)
        end

        def permitted_parameter_keys
          # json-api: fields, sort
          super + [:id, :format, :type, :language, :q, :modified_since, :created_since, :deleted_since, :include]
        end

        private

        def build_search_query
          query = DataCycleCore::Filter::Search.new(permitted_params.fetch(:language, 'de'))
          query
        end

        def prepare_url_parameters
          @url_parameters = permitted_params.reject { |k, _| k == 'format' }
          @include_parameters = permitted_params.dig(:include)&.split(',') || []
        end

        def content_data_type
          object_type_string = permitted_params[:type] || controller_name
          object_type = DataCycleCore.content_tables.find { |object| object == object_type_string }
          return unless object_type
          ('DataCycleCore::' + object_type.singularize.classify).constantize
        end

        def apply_ordering(query)
          if permitted_params[:q].blank?
            query
          else
            query.order(DataCycleCore::Filter::ObjectBrowserQueryBuilder.get_order_by_query_string(permitted_params[:q]))
          end
        end
      end
    end
  end
end
