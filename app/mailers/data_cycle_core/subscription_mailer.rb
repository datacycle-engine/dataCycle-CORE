# frozen_string_literal: true

module DataCycleCore
  class SubscriptionMailer < ApplicationMailer
    def notify(user, contents)
      @user = user
      @contents = contents
      attachments.inline[DataCycleCore.logo['inverted']] = File.read(Rails.root.join('app', 'assets', 'images', DataCycleCore.logo['inverted']))
      mail(to: @user.email, subject: t('common.abo_changed_title', count: @contents.size, locale: DataCycleCore.ui_language))
    end
  end
end
