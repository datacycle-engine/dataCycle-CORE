# frozen_string_literal: true

module DataCycleCore
  module Api
    module V4
      class UsersController < ::DataCycleCore::Api::V4::ContentsController
        before_action :prepare_url_parameters
        before_action :init_user_api_feature, except: :index
        helper 'data_cycle_core/email'

        def permitted_params
          @permitted_params ||= params.permit(*permitted_parameter_keys)
        end

        def index
          @user_data = current_user
          @watch_lists = DataCycleCore::WatchList.accessible_by(current_ability).without_my_selection
          @stored_filter = DataCycleCore::StoredFilter.accessible_by(current_ability, :api).named
        end

        def show
          @user = DataCycleCore::User.find(params[:id])
          authorize! :show, @user

          @user.user_api_feature = @user_api_feature

          render json: @user.as_user_api_json.deep_transform_keys { |k| k.camelize(:lower) }
        end

        def create
          authorize! :create_user, current_user

          @user = DataCycleCore::User.new(user_params.merge(creator: current_user))
          @user.user_api_feature = @user_api_feature
          @user.user_api_feature.user = @user
          @user.role = @user.user_api_feature.allowed_role!(role_params[:rank])
          @user.user_groups = @user.user_api_feature.default_user_groups if @user.user_groups.none?
          @user.jti = SecureRandom.uuid
          @user.attributes = layout_params

          if @user.save
            @user.user_api_feature.notify_users if @user.user_api_feature.new_user_notification?

            render json: @user.as_user_api_json.merge(@user.generate_user_token.to_h).deep_transform_keys { |k| k.to_s.camelize(:lower) }, status: :created
          else
            render json: { errors: @user.errors }, status: :unprocessable_entity
          end
        rescue DataCycleCore::Error::Api::UserApiRankError => e
          render(json: { errors: { rank: [e.message] } }, status: :unprocessable_entity)
        end

        def update
          authorize! :update, current_user

          current_user.user_api_feature = @user_api_feature
          current_user.attributes = user_params.except(:additional_attributes)
          (current_user.additional_attributes ||= {}).merge!(user_params[:additional_attributes] || {})

          current_user.attributes = layout_params

          if current_user.save
            render json: current_user.as_user_api_json.merge(current_user.generate_user_token.to_h), status: :ok
          else
            render json: { errors: current_user.errors }, status: :unprocessable_entity
          end
        end

        def password
          authorize! :reset_password, :user_api

          user = DataCycleCore::User.find_by!(email: password_params[:email])
          user.user_api_feature = @user_api_feature
          user.attributes = layout_params

          user.send_reset_password_instructions
        end

        def resend_confirmation
          authorize! :confirm, :user_api

          user = DataCycleCore::User.find_by!(email: password_params[:email])
          user.user_api_feature = @user_api_feature
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

          user = User.reset_password_by_token(password_params.slice(:password, :reset_password_token))
          user.user_api_feature = @user_api_feature

          if user.errors.present?
            render json: { errors: user.errors }, status: :unprocessable_entity
          else
            render json: user.as_user_api_json.merge(user.generate_user_token.to_h), status: :ok
          end
        end

        def confirm
          authorize! :confirm, :user_api

          user = User.confirm_by_token(password_params[:confirmation_token])
          user.user_api_feature = @user_api_feature

          if user.errors.present?
            render json: { errors: user.errors }, status: :unprocessable_entity
          else
            head :ok
          end
        end

        private

        def layout_params
          layout_hash = params
            .permit(:mailerLayout, :viewerLayout, :redirectUrl, :forwardToUrl).to_h
            .deep_transform_keys(&:underscore)
            .with_indifferent_access

          helpers.layout_params(layout_hash, @user_api_feature&.current_issuer)
        end

        def password_params
          params
            .permit(:email, :mailerLayout, :viewerLayout, :redirectUrl, :password, :passwordConfirmation, :resetPasswordToken, :confirmationToken, :forwardToUrl).to_h
            .deep_transform_keys(&:underscore)
            .with_indifferent_access
        end

        def user_params
          @user_api_feature.parsed_user_params(params)
        end

        def role_params
          params.permit(:rank)
        end

        def init_user_api_feature
          raise CanCan::AccessDenied, 'UserApi feature not activated' unless DataCycleCore::Feature::UserApi.enabled?

          @user_api_feature = DataCycleCore::Feature::UserApi.new(request.env['data_cycle.feature.user_api.issuer'])
        end
      end
    end
  end
end
