# frozen_string_literal: true

module DataCycleCore
  class OmniauthController < Devise::OmniauthCallbacksController
    def pixelpoint_aad_v2
      @user = DataCycleCore::User.from_omniauth(request.env['omniauth.auth'])
      sign_in_and_redirect @user
    end
  end
end
