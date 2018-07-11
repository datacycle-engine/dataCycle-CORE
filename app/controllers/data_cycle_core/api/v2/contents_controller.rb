# frozen_string_literal: true

module DataCycleCore
  module Api
    module V2
      class ContentsController < Api::V2::ApiBaseController
        include DataCycleCore::Api::V2::Filter
        before_action :prepare_url_parameters

        ALLOWED_INCLUDE_PARAMETERS = ['linked', 'translations'].freeze

        def index
          query = build_search_query
          query = filter_query(query)
          query = apply_ordering(query)

          @pagination_contents = apply_paging(query)
          @contents = @pagination_contents.map(&:content_data)

          render 'index'
        end

        def show
          object_type = content_data_type
          return if object_type.nil?
          @content = object_type
            .includes({ classifications: [], translations: [] })
            .find(permitted_params[:id])
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

          if permitted_params[:deleted_since]
            deleted_contents = deleted_contents.where(
              DataCycleCore::CreativeWork::History.arel_table[:deleted_at].gteq(Time.zone.parse(permitted_params[:deleted_since]))
            )
          end

          @contents = apply_paging(deleted_contents)
        end

        def permitted_parameter_keys
          # json-api: fields, sort
          super + [:id, :format, :type, :language, :q, :modified_since, :created_since, :deleted_since, :include, { filter: [{ classifications: [] }] }]
        end

        private

        def build_search_query
          query = DataCycleCore::Filter::Search.new(@language)
          query
        end

        def prepare_url_parameters
          @url_parameters = permitted_params.reject { |k, _| k == 'format' }
          @include_parameters = (permitted_params.dig(:include)&.split(',') || []).select { |v| ALLOWED_INCLUDE_PARAMETERS.include?(v) }.sort
          @language = permitted_params.dig(:language) || I18n.available_locales.first.to_s
        end

        def content_data_type
          object_type_string = permitted_params[:type] || controller_name
          object_type = DataCycleCore.content_tables.find { |object| object == object_type_string }
          return unless object_type
          ('DataCycleCore::' + object_type.singularize.classify).constantize
        end

      end
    end
  end
end
