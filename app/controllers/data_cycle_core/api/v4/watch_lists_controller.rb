# frozen_string_literal: true

module DataCycleCore
  module Api
    module V4
      class WatchListsController < ::DataCycleCore::Api::V4::ContentsController
        before_action :prepare_url_parameters

        def index
          if permitted_params[:user_email].present?
            @watch_lists = DataCycleCore::WatchList
              .accessible_by(DataCycleCore::Ability.new(User.find_by(email: permitted_params[:user_email]), session)).without_my_selection
          else
            @watch_lists = DataCycleCore::WatchList.accessible_by(current_ability).without_my_selection
          end
          @watch_lists = apply_paging(@watch_lists)
        end

        def show
          redirect_to api_v4_stored_filter_path(id: permitted_params[:id], sl: 1, format: request.format.symbol)
        end

        def create
          @watch_list = current_user.watch_lists.create(full_path: "Download #{Time.zone.now.strftime('%d.%m.%Y - %H:%M')}", thing_ids: Array(permitted_params[:thing_id]))

          render json: @watch_list.as_json(only: [:id, :name]).deep_transform_keys { |k| k.camelize(:lower) }
        end

        def add_item
          @watch_list = DataCycleCore::WatchList.find(permitted_params[:id])
          @content_object = DataCycleCore::Thing.find(permitted_params[:thing_id])

          @watch_list.things << @content_object unless @watch_list.things.include?(@content_object)
        end

        def remove_item
          @watch_list = DataCycleCore::WatchList.find(permitted_params[:id])
          @content_object = DataCycleCore::Thing.find(permitted_params[:thing_id])

          @watch_list.things.destroy(@content_object) if @watch_list.things.include?(@content_object)
        end

        private

        def permitted_parameter_keys
          super + [:user_email, :id, :thing_id]
        end
      end
    end
  end
end
