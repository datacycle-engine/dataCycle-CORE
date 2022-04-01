# frozen_string_literal: true

module DataCycleCore
  class SessionsController < Devise::SessionsController
    include DataCycleCore::ErrorHandler

    before_action :set_locale

    layout 'data_cycle_core/devise'

    private

    def set_locale
      I18n.locale = helpers.active_ui_locale
    end
  end
end
