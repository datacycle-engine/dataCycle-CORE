# frozen_string_literal: true

module DataCycleCore
  module Api
    module V4
      class UsersController < ::DataCycleCore::Api::V4::ContentsController
        before_action :prepare_url_parameters

        def index
          @user_data = current_user
          @watch_lists = DataCycleCore::WatchList.accessible_by(current_ability)
          @stored_filter = DataCycleCore::StoredFilter.accessible_by(current_ability).where("'#{current_user.id}' = ANY (api_users)")
        end

        def create
          @user = ('DataCycleCore::' + controller_name.singularize.classify).constantize.new(user_params.merge(creator: current_user))
          rank = DataCycleCore.features.dig(:user_api, :default_rank).to_i

          if role_params[:rank].present? && DataCycleCore.features.dig(:user_api, :allowed_ranks)&.include?(role_params[:rank].to_i)
            rank = role_params[:rank].to_i
          elsif role_params[:rank].present?
            render(json: { errors: { rank: [I18n.t('validation.errors.rank_not_allowed', locale: DataCycleCore.ui_language)] } }, status: :unprocessable_entity) && return
          end

          @user.role = DataCycleCore::Role.find_by(rank: rank)
          @user.jti = SecureRandom.uuid

          if @user.save
            render json: @user.as_json(only: Array(DataCycleCore.features.dig(:user_api, :user_params)) + [:id]).transform_keys { |k| k.camelize(:lower) }.merge({
              rank: @user.role&.rank,
              token: DataCycleCore::JsonWebToken.encode(user_id: @user.id, jti: @user.jti)
            }), status: :created
          else
            render json: { errors: @user.errors }, status: :unprocessable_entity
          end
        end

        private

        def user_params
          params.require(controller_name.singularize.to_sym).permit(DataCycleCore.features.dig(:user_api, :user_params))
        end

        def role_params
          params.require(controller_name.singularize.to_sym).permit(:rank)
        end
      end
    end
  end
end
