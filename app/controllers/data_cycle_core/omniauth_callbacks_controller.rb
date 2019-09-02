# frozen_string_literal: true

module DataCycleCore
  class OmniauthCallbacksController < Devise::OmniauthCallbacksController
    def openid_connect
      @user = User.from_omniauth(request.env['omniauth.auth'])

      if @user.persisted?
        flash[:success] = I18n.t :success, scope: [:devise, :omniauth_callbacks], kind: request.env['omniauth.strategy']&.class&.name&.demodulize, locale: DataCycleCore.ui_language
        sign_in_and_redirect @user, event: :authentication
      else
        redirect_to new_user_session_path
      end
    end

    def failure
      flash[:error] = I18n.t :failure, scope: [:devise, :omniauth_callbacks], kind: request.env['omniauth.error.strategy']&.class&.name&.demodulize, reason: request.env['omniauth.error.type'], locale: DataCycleCore.ui_language
      redirect_to new_user_session_path
    end
  end
end
