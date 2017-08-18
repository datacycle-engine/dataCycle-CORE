module DataCycleCore
  class DataLinkMailer < ApplicationMailer
    def mail_link(user, receiver, url, action_text)
      @user = user
      @url  = url
      @action  = action_text
      mail(to: receiver, cc: user.email, subject: 'Generierter Link zu einem Inhalt')
    end
  end
end
