# frozen_string_literal: true

module DataCycleCore
  class UserMailer < Devise::Mailer
    module Localized
      ['confirmation_instructions', 'reset_password_instructions'].each do |method|
        define_method(method) do |resource, *args|
          @locale = resource.try(:ui_locale) || I18n.available_locales.first

          I18n.with_locale(@locale) do
            super(resource, *args)
          end
        end
      end
    end

    prepend Localized
  end
end
