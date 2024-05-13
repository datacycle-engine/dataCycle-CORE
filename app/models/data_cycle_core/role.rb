# frozen_string_literal: true

module DataCycleCore
  class Role < ApplicationRecord
    has_many :users, dependent: :nullify

    def translated_name(locale = I18n.locale)
      I18n.t("roles.#{name}", default: name, locale:)
    end

    def to_select_option(locale = DataCycleCore.ui_locales.first)
      DataCycleCore::Filter::SelectOption.new(
        id,
        ActionController::Base.helpers.safe_join([
          ActionController::Base.helpers.tag.i(class: 'fa dc-type-icon role-icon'),
          translated_name(locale)
        ].compact, ' '),
        model_name.param_key,
        "#{model_name.human(count: 1, locale:)}: #{translated_name(locale)}"
      )
    end

    def self.to_select_options(locale = DataCycleCore.ui_locales.first)
      all.map { |v| v.to_select_option(locale) }
    end
  end
end
