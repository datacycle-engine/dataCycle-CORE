module DataCycleCore
  class EditLinkMailer < ApplicationMailer

    default from: 'no-reply@datacycle.at'
    
     def mail_link(user, url, action_text)
      @user = user
      @url  = url
      @action  = action_text
      mail(to: @user.email, subject: 'Generierter Link zu einem Inhalt')
     end

  end
end
