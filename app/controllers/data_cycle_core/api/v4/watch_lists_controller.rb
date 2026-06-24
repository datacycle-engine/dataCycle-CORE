# frozen_string_literal: true

module DataCycleCore
  module Api
    module V4
      class WatchListsController < ::DataCycleCore::Api::V4::ContentsController
        before_action :prepare_url_parameters

        def index
          @watch_lists = if permitted_params[:user_email].present?
                           target_user = User.find_by(email: permitted_params[:user_email])
                           authorize! :show, target_user unless target_user == current_user
                           DataCycleCore::WatchList
                             .accessible_by(DataCycleCore::Ability.new(target_user, session)).without_my_selection
                         else
                           DataCycleCore::WatchList.accessible_by(current_ability).without_my_selection
                         end
          @watch_lists = apply_paging(@watch_lists)
        end

        def show
          redirect_to api_v4_stored_filter_path(format: request.format.symbol, **permitted_params.except(:id).merge(sl: 1))
        end

        def create
          authorize! :create, DataCycleCore::WatchList

          @watch_list = current_user.watch_lists.create(full_path: "Download #{Time.zone.now.strftime('%d.%m.%Y - %H:%M')}", thing_ids: Array(permitted_params[:thing_id]))

          render json: @watch_list.as_json(only: [:id, :name]).deep_transform_keys { |k| k.camelize(:lower) }
        end

        def add_item
          @watch_list = DataCycleCore::WatchList.find(item_params[:id])
          authorize! :add_item, @watch_list
          @content_object = DataCycleCore::Thing.find(item_params[:thing_id])

          @watch_list.things << @content_object unless @watch_list.things.include?(@content_object)
        end

        def remove_item
          @watch_list = DataCycleCore::WatchList.find(item_params[:id])
          authorize! :remove_item, @watch_list
          @content_object = DataCycleCore::Thing.find(item_params[:thing_id])

          @watch_list.things.destroy(@content_object) if @watch_list.things.include?(@content_object)
        end

        private

        def item_params
          params.transform_keys(&:underscore).permit(:thing_id, :id)
        end

        def permitted_parameter_keys
          super + [:user_email, :id, :thing_id]
        end
      end
    end
  end
end
