# frozen_string_literal: true

module DataCycleCore
  module Api
    module V1
      class WatchListsController < Api::V1::ApiBaseController
        def index
          @watch_lists = if permitted_params[:user_email].present?
                           target_user = User.find_by(email: permitted_params[:user_email])
                           authorize! :show, target_user unless target_user == current_user
                           DataCycleCore::WatchList
                             .accessible_by(DataCycleCore::Ability.new(target_user, session)).without_my_selection
                         else
                           DataCycleCore::WatchList.accessible_by(current_ability).without_my_selection
                         end

          render plain: {
            collections: @watch_lists.map do |l|
              {
                id: l.id,
                name: l.name,
                url: api_v1_collection_url(l),
                item_count: l.watch_list_data_hashes.count
              }
            end
          }.to_json, content_type: 'application/json'
        end

        def show
          @watch_list = DataCycleCore::WatchList.find(permitted_params[:id])
        end

        private

        def permitted_parameter_keys
          super + [:user_email, :id]
        end
      end
    end
  end
end
