module DataCycleCore
  class SubscriptionMailer < ApplicationMailer
    def notify(user, content)
      @user = user
      @content = content
      mail(to: @user.email, subject: 'Abonnierter Inhalt wurde geändert')
    end
  end
end
