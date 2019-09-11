# frozen_string_literal: true

module DataCycleCore
  class ApplicationMailer < ActionMailer::Base
    layout 'data_cycle_core/mailer'
    add_template_helper(DataCycleCore::EmailHelper)
  end
end
