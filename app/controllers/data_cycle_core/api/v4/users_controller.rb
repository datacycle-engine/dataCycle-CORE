# frozen_string_literal: true

module DataCycleCore
  module Api
    module V4
      class UsersController < ::DataCycleCore::Api::V4::ContentsController
        before_action :prepare_url_parameters
        before_action :check_feature_enabled, except: :index

        def index
          @user_data = current_user
          @watch_lists = DataCycleCore::WatchList.accessible_by(current_ability)
          @stored_filter = DataCycleCore::StoredFilter.accessible_by(current_ability, :api).where("'#{current_user.id}' = ANY (api_users)").where.not(name: nil)
        end

        def show
          @user = DataCycleCore::User.find(params[:id])
          authorize! :show, @user

          render json: @user.as_user_api_json.deep_transform_keys { |k| k.camelize(:lower) }
        end

        def create
          authorize! :create_user, current_user

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
            render json: @user.as_user_api_json.merge({
              token: DataCycleCore::JsonWebToken.encode(payload: { user_id: @user.id, jti: @user.jti })
            }).deep_transform_keys { |k| k.to_s.camelize(:lower) }, status: :created
          else
            render json: { errors: @user.errors }, status: :unprocessable_entity
          end
        end

        private

        def user_params
          user_keys = DataCycleCore.features.dig(:user_api, :user_params).deep_transform_keys { |k| k.camelize(:lower) }
          authorized_params = Array(user_keys.select { |_, v| v.nil? }.keys)
          authorized_params.concat(Array(user_keys.compact.map { |k, _| { "#{k}Ids" => [] } }))

          params.permit(authorized_params).transform_keys(&:underscore)
        end

        def role_params
          params.permit(:rank)
        end

        def check_feature_enabled
          raise CanCan::AccessDenied, 'feature not activated' unless DataCycleCore.features.dig(:user_api, :enabled)
        end
      end
    end
  end
end
