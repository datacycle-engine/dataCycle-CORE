# frozen_string_literal: true

module DataCycleCore
  class ApplicationMailer < ActionMailer::Base
    helper DataCycleCore::EmailHelper
    layout 'data_cycle_core/mailer'
  end
end
