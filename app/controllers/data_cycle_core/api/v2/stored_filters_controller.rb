# frozen_string_literal: true

module DataCycleCore
  module Api
    module V2
      class StoredFiltersController < Api::V2::ContentsController
        include DataCycleCore::Filter

        def show
          @stored_filter = DataCycleCore::StoredFilter.find(permitted_params[:id])

          raise ActiveRecord::RecordNotFound unless @stored_filter.api_users.include?(current_user.id)

          query = apply_filter(filter_id: permitted_params[:id], api_only: true)
          query = query.fulltext_search(permitted_params[:q]) if permitted_params[:q]

          if permitted_params&.dig(:filter, :classifications)
            permitted_params.dig(:filter, :classifications).map { |classifications|
              classifications.split(',').map(&:strip).reject(&:blank?)
            }.reject(&:empty?).each do |classifications|
              query = query.classification_alias_ids(classifications)
            end
          end

          query = query.includes(content_data: [:classifications, :translations, :watch_lists])

          query = apply_ordering(query)

          @pagination_contents = apply_paging(query)
          @contents = @pagination_contents.map(&:content_data)
        end
      end
    end
  end
end
