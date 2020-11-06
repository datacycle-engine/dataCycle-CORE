# frozen_string_literal: true

module DataCycleCore
  class ConfirmationsController < Devise::ConfirmationsController
    include DataCycleCore::ErrorHandler
  end
end
