# frozen_string_literal: true

module DataCycleCore
  class UserMailer < Devise::Mailer
    module Localized
      ['confirmation_instructions', 'reset_password_instructions'].each do |method|
        define_method(method) do |resource, token, opts = {}|
          @locale = resource.try(:ui_locale) || I18n.available_locales.first
          opts[:template_name] = first_existing_action_template(resource.template_namespaces)
          opts[:subject] = first_available_i18n_t("devise.mailer.#{method}.?.subject", resource.template_namespaces, locale: @locale)

          super(resource, token, opts)
        end
      end
    end

    prepend Localized
  end
end
