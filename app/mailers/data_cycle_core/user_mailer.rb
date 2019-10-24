# frozen_string_literal: true

module DataCycleCore
  class UserMailer < Devise::Mailer
    helper DataCycleCore::EmailHelper
    layout 'data_cycle_core/mailer'
  end
end
