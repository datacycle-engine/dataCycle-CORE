# frozen_string_literal: true

module DataCycleCore
  class PasswordsController < Devise::PasswordsController
    protected

    def after_resetting_password_path_for(_resource)
      Devise.sign_in_after_reset_password ? root_path : new_session_path(resource_name)
    end
  end
end
