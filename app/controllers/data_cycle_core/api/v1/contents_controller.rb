# frozen_string_literal: true

module DataCycleCore
  module Api
    module V1
      class ContentsController < Api::V1::ApiBaseController
        before_action :prepare_url_parameters, only: :index

        def index
        end

        def show
          return if permitted_params[:type].nil? || permitted_params[:type] != 'things'

          @content = DataCycleCore::Thing
            .includes({ classifications: [], translations: [] })
            .find(permitted_params[:id])
        end

        def update
          @content = DataCycleCore::Thing
            .includes({ classifications: [], translations: [] })
            .find(permitted_params[:id])

          render json: @content.get_data_hash
        end

        def destroy
          @content = DataCycleCore::Thing
            .includes({ classifications: [], translations: [] })
            .find(permitted_params[:id])
        end

        def search
          query = build_search_query
          query = query.modified_at({ min: permitted_params[:modified_since] }) if permitted_params[:modified_since]
          query = query.created_at({ min: permitted_params[:created_since] }) if permitted_params[:created_since]
          query = query.in_validity_period unless permitted_params[:modified_since] || permitted_params[:created_since]
          query = query.fulltext_search(permitted_params[:search]) if permitted_params[:search]
          query = apply_ordering(query)

          @total = query.count
          @contents = apply_paging(query)
        end

        def deleted
          deleted_contents = DataCycleCore::Thing::History.where.not(deleted_at: nil).where.not(content_type: 'embedded')

          @language = permitted_params.fetch(:language) { current_user.default_locale }

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
          query = DataCycleCore::Filter::Search.new(permitted_params.fetch(:language) { 'de' })
          query
        end

        def prepare_url_parameters
          @url_parameters = permitted_params.except('format')
        end

        def apply_ordering(query)
          query = query.sort_fulltext_search('DESC', permitted_params[:search]) if permitted_params[:search]
          query
        end
      end
    end
  end
end
