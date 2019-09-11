# frozen_string_literal: true

module DataCycleCore
  class SubscriptionMailer < ApplicationMailer
    def notify(user, contents)
      @user = user
      @contents = contents
      logo_file_path = Rails.root.join('app', 'assets', 'images', DataCycleCore.logo['inverted'])
      logo_file_path = DataCycleCore::Engine.root.join('app', 'assets', 'images', DataCycleCore.logo['inverted']) unless File.exist?(logo_file_path)
      attachments.inline[DataCycleCore.logo['inverted']] = File.read(logo_file_path)
      mail(to: @user.email, subject: t('common.abo_changed_title', count: @contents.size, locale: DataCycleCore.ui_language))
    end
  end
end
