# frozen_string_literal: true

module DataCycleCore
  class UserMailer < Devise::Mailer
    helper DataCycleCore::EmailHelper
    layout -> { @resource.try(:mailer_layout) || 'data_cycle_core/mailer' }
  end
end
