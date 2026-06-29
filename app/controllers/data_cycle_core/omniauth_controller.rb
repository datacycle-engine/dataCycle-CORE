# frozen_string_literal: true

module DataCycleCore
  class OmniauthController < Devise::OmniauthCallbacksController
    def pixelpoint_aad_v2
      @user = DataCycleCore::User.from_omniauth(request.env['omniauth.auth'])

      # from_omniauth returns nil when the identity is rejected (blank or non-allowlisted email
      # domain — DC-25); never try to sign in a nil/unsaved resource.
      if @user&.persisted?
        sign_in_and_redirect @user
      else
        flash[:alert] = I18n.t('devise.omniauth_callbacks.failure', kind: 'Pixelpoint', reason: I18n.t('devise.omniauth_callbacks.email_domain_not_allowed'))
        redirect_to after_omniauth_failure_path_for(:user)
      end
    end
  end
end
