# frozen_string_literal: true

module DataCycleCore
  class DataLinkMailer < ApplicationMailer
    def mail_link(data_link, url)
      @data_link = data_link
      @user = data_link.creator
      @receiver = data_link.receiver

      if data_link.item.is_a?(DataCycleCore::WatchList)
        @title = data_link.item.try(:title)
      elsif data_link.item.class.table_name == 'things'
        I18n.with_locale(data_link.item.first_available_locale) do
          @title = data_link.item.try(:title)
        end
      end
      @url = url
      mail(to: @receiver.email, cc: @user.email, subject: 'Geteilter Link zu einem Inhalt')
    end
  end
end
