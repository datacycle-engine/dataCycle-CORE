# frozen_string_literal: true

module DataCycleCore
  module Api
    module V4
      class AuthenticationController < ::DataCycleCore::Api::V4::ApiBaseController
        def login
          @user = User.find_by(email: login_params[:email])

          raise CanCan::AccessDenied, 'invalid or missing authentication token' unless @user&.valid_password?(params[:password])

          @user.update_column(:jti, SecureRandom.uuid) # rubocop:disable Rails/SkipsModelValidations

          time = 24.hours.from_now
          token = DataCycleCore::JsonWebToken.encode({ user_id: @user.id, jti: @user.jti }, time.to_i)

          render json: { token: token, exp: time.strftime('%m-%d-%Y %H:%M'),
                         email: @user.email }, status: :ok
        end

        def logout
          current_user.update_column(:jti, SecureRandom.uuid) # rubocop:disable Rails/SkipsModelValidations

          head :no_content
        end

        private

        def login_params
          params.permit(:email, :password)
        end
      end
    end
  end
end
