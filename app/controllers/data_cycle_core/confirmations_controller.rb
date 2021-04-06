# frozen_string_literal: true

module DataCycleCore
  class ConfirmationsController < Devise::ConfirmationsController
    include DataCycleCore::ErrorHandler

    layout 'data_cycle_core/devise'
  end
end
