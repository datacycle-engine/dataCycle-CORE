# frozen_string_literal: true

module DataCycleCore
  class UserMailer < Devise::Mailer
    module Localized
      ['confirmation_instructions', 'reset_password_instructions'].each do |method|
        define_method(method) do |resource, *args|
          @locale = resource.try(:ui_locale) || I18n.available_locales.first
          @current_issuer = resource.try(:user_api_feature)&.current_issuer

          I18n.with_locale(@locale) do
            super(resource, *args)
          end
        end
      end
    end

    prepend Localized
  end
end
