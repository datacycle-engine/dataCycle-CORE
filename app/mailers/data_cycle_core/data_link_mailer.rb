module DataCycleCore
  class DataLinkMailer < ApplicationMailer
    def mail_link(user, receiver, url, action_text, comment)
      @user = user
      @url = url
      @action = action_text
      @comment = comment
      mail(to: receiver, cc: user.email, subject: 'Generierter Link zu einem Inhalt')
    end
  end
end
