module DataCycleCore
  class SubscriptionMailer < ApplicationMailer
    def notify(user, content)
      @user = user
      @content = content
      mail(to: @user.email, subject: 'Contents Changed')
    end
  end
end
