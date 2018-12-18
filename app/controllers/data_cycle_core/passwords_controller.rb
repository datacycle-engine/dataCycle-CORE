# frozen_string_literal: true

module DataCycleCore
  class PasswordsController < Devise::PasswordsController
    def create
      resource = resource_class.find_or_initialize_with_errors(resource_class.reset_password_keys, resource_params, :not_found)

      if resource.respond_to?(:recoverable?) && !resource.recoverable?
        set_flash_message(:alert, :not_recoverable)
        redirect_to new_password_path(resource_name)
      else
        super
      end
    end

    protected

    def after_resetting_password_path_for(_resource)
      Devise.sign_in_after_reset_password ? root_path : new_session_path(resource_name)
    end
  end
end
