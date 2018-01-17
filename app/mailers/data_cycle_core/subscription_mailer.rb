module DataCycleCore
  class SubscriptionMailer < ApplicationMailer
    def notify(user, contents)
      @user = user
      @contents = contents
      mail(to: @user.email, subject: 'Abonnierte Inhalte wurden geändert')
    end
  end
end
