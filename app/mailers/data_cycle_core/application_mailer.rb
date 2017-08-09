module DataCycleCore
  class ApplicationMailer < ActionMailer::Base
    default from: 'no-reply@datacycle.at'
    layout 'mailer'
  end
end
