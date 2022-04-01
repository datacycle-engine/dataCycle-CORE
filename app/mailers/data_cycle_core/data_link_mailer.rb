# frozen_string_literal: true

module DataCycleCore
  class DataLinkMailer < ApplicationMailer
    def mail_link(data_link, url)
      @data_link = data_link
      @user = data_link.creator
      @receiver = data_link.receiver
      @locale = data_link.locale.presence || @receiver.ui_locale

      if data_link.item.is_a?(DataCycleCore::WatchList) || data_link.item.is_a?(DataCycleCore::StoredFilter)
        @title = data_link.item.try(:name)
      elsif data_link.item.class.table_name == 'things'
        I18n.with_locale(data_link.item.first_available_locale) do
          @title = data_link.item.try(:title)
        end
      end

      @url = url

      mail(to: @receiver.email, cc: @user.email, from: t('data_link_mailer.from', from: self.class.default[:from], locale: @locale, default: self.class.default[:from]), subject: t('data_link_mailer.send_subject', locale: @locale))
    end

    def mail_external_link(data_link, url, instructions_url = nil)
      @instructions_url = instructions_url

      mail_link(data_link, url)
    end

    def updated_items(data_link)
      return unless data_link.item.is_a?(DataCycleCore::WatchList)

      @data_link = data_link
      @user = data_link.creator
      @receiver = data_link.receiver
      @locale = data_link.locale.presence || @receiver.ui_locale
      @title = data_link.item.try(:name)
      @url = data_link_url(data_link)

      mail(to: @receiver.email, cc: @user.email, from: t('data_link_mailer.from', from: self.class.default[:from], locale: @locale, default: self.class.default[:from]), subject: t('data_link_mailer.update_subject', locale: @locale))
    end
  end
end
