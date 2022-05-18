# frozen_string_literal: true

module DataCycleCore
  module Api
    module V4
      class UsersController < ::DataCycleCore::Api::V4::ContentsController
        before_action :prepare_url_parameters
        before_action :check_feature_enabled, except: :index

        def permitted_params
          @permitted_params ||= params.permit(*permitted_parameter_keys)
        end

        def index
          @user_data = current_user
          @watch_lists = DataCycleCore::WatchList.accessible_by(current_ability).without_my_selection
          @stored_filter = DataCycleCore::StoredFilter.accessible_by(current_ability, :api).where("'#{current_user.id}' = ANY (api_users)").where.not(name: nil)
        end

        def show
          @user = DataCycleCore::User.find(params[:id])
          authorize! :show, @user

          render json: @user.as_user_api_json.deep_transform_keys { |k| k.camelize(:lower) }
        end

        def create
          authorize! :create_user, current_user

<<<<<<< HEAD
          @user = ('DataCycleCore::' + controller_name.singularize.classify).constantize.new(user_params.merge(creator: current_user))
=======
          @user = DataCycleCore::User.new(user_params.merge(creator: current_user))
>>>>>>> old/develop
          rank = DataCycleCore.features.dig(:user_api, :default_rank).to_i

          if role_params[:rank].present? && DataCycleCore.features.dig(:user_api, :allowed_ranks)&.include?(role_params[:rank].to_i)
            rank = role_params[:rank].to_i
          elsif role_params[:rank].present?
            render(json: { errors: { rank: ['RANK_NOT_ALLOWED'] } }, status: :unprocessable_entity) && return
          end

          @user.role = DataCycleCore::Role.find_by(rank: rank)
          @user.user_groups = DataCycleCore::Feature::UserApi.default_user_groups unless DataCycleCore::Feature::UserApi.default_user_groups.nil?
          @user.jti = SecureRandom.uuid
<<<<<<< HEAD
=======
          @user.attributes = layout_params
>>>>>>> old/develop

          if @user.save
            DataCycleCore::Feature::UserApi.notify_users(@user) if DataCycleCore::Feature::UserApi.new_user_notification?

            render json: @user.as_user_api_json.merge({
              token: DataCycleCore::JsonWebToken.encode(payload: { user_id: @user.id, jti: @user.jti })
            }).deep_transform_keys { |k| k.to_s.camelize(:lower) }, status: :created
          else
            render json: { errors: @user.errors }, status: :unprocessable_entity
          end
        end

<<<<<<< HEAD
=======
        def update
          authorize! :update, current_user

          current_user.attributes = user_params.except(:additional_attributes)
          (current_user.additional_attributes ||= {}).merge!(user_params[:additional_attributes] || {})

          current_user.attributes = layout_params

          if current_user.save
            render json: current_user.as_user_api_json.merge({
              token: DataCycleCore::JsonWebToken.encode(payload: { user_id: current_user.id, jti: current_user.jti })
            }), status: :ok
          else
            render json: { errors: current_user.errors }, status: :unprocessable_entity
          end
        end

>>>>>>> old/develop
        def password
          authorize! :reset_password, :user_api
          raise CanCan::AccessDenied, 'not_recoverable' unless DataCycleCore::Feature::UserApi.enabled?

<<<<<<< HEAD
          user = User.find_by!(email: password_params[:email])
          user.mailer_layout = password_params[:mailerLayout].presence&.prepend('data_cycle_core/')
          user.viewer_layout = password_params[:viewerLayout].presence&.prepend('data_cycle_core/')
          user.redirect_url = password_params[:redirectUrl].presence
=======
          user = DataCycleCore::User.find_by!(email: password_params[:email])
          user.attributes = layout_params
>>>>>>> old/develop

          user.send_reset_password_instructions
        end

<<<<<<< HEAD
        private

        def password_params
          params.permit(:email, :mailerLayout, :viewerLayout, :redirectUrl)
        end

        def user_params
          user_keys = DataCycleCore.features.dig(:user_api, :user_params).deep_transform_keys { |k| k.camelize(:lower) }
          authorized_params = Array(user_keys.select { |_, v| v.nil? }.keys)
          authorized_params.concat(Array(user_keys.compact.map { |k, _| { "#{k}Ids" => [] } }))

          params.permit(authorized_params).transform_keys(&:underscore)
=======
        def resend_confirmation
          authorize! :confirm, :user_api

          user = DataCycleCore::User.find_by!(email: password_params[:email])
          user.attributes = layout_params
          user.resend_confirmation_instructions if DataCycleCore::User.reconfirmable

          if user.errors.present?
            render json: { errors: user.errors }, status: :unprocessable_entity
          else
            head :ok
          end
        end

        def change_password
          authorize! :reset_password, :user_api

          user = User.reset_password_by_token(password_params.slice(:password, :password_confirmation, :reset_password_token))

          if user.errors.present?
            render json: { errors: user.errors }, status: :unprocessable_entity
          else
            render json: user.as_user_api_json.merge({
              token: DataCycleCore::JsonWebToken.encode(payload: { user_id: user.id, jti: user.jti })
            }), status: :ok
          end
        end

        def confirm
          authorize! :confirm, :user_api

          user = User.confirm_by_token(password_params[:confirmation_token])

          if user.errors.present?
            render json: { errors: user.errors }, status: :unprocessable_entity
          else
            head :ok
          end
        end

        private

        def layout_params
          params
            .permit(:mailerLayout, :viewerLayout, :redirectUrl, :forwardToUrl).to_h
            .deep_transform_keys(&:underscore)
            .with_indifferent_access
            .tap { |u|
              u[:mailer_layout].presence&.prepend('data_cycle_core/')
              u[:viewer_layout].presence&.prepend('data_cycle_core/')
            }
            .compact_blank
        end

        def password_params
          params
            .permit(:email, :mailerLayout, :viewerLayout, :redirectUrl, :password, :passwordConfirmation, :resetPasswordToken, :confirmationToken, :forwardToUrl).to_h
            .deep_transform_keys(&:underscore)
            .with_indifferent_access
            .tap { |u| u[:password_confirmation] = u[:password] if u.key?(:password) && u[:password_confirmation].blank? }
        end

        def user_params
          params
            .permit(DataCycleCore::Feature::UserApi.allowed_user_params).to_h
            .deep_transform_keys(&:underscore)
            .with_indifferent_access
>>>>>>> old/develop
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
