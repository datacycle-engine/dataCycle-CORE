# frozen_string_literal: true

module DataCycleCore
  class DataLinkMailer < ApplicationMailer
    def mail_link(data_link, url)
      @data_link = data_link
      @user = data_link.creator
      @receiver = data_link.receiver

      if data_link.item.is_a?(DataCycleCore::WatchList)
        @headline = data_link.item.try(:headline)
      elsif DataCycleCore.content_tables.include?(data_link.item.class.table_name)
        I18n.with_locale(data_link.item.first_available_locale) do
          @headline = data_link.item.try(:headline)
        end
      end
      @url = url
      mail(to: @receiver.email, cc: @user.email, subject: 'Geteilter Link zu einem Inhalt')
    end
  end
end
