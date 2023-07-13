# frozen_string_literal: true

module DataCycleCore
  class DataLinkMailer < ApplicationMailer
    def mail_link(data_link, url)
      @data_link ||= data_link
      @user ||= @data_link.creator
      @receiver ||= @data_link.receiver
      @resource ||= @receiver
      @locale ||= @data_link.locale.presence || @receiver.ui_locale
      @title ||= data_link_item_title
      @url ||= url
      @subject ||= first_available_i18n_t('data_link_mailer.?.send_subject', @resource.template_namespaces, title: @title, locale: @locale)

      mail(
        template_name: first_existing_action_template(@resource.template_namespaces),
        to: @receiver.email,
        cc: @user.email,
        bcc: DataCycleCore.data_link_bcc,
        from: t('data_link_mailer.from', from: self.class.default[:from], locale: @locale, default: self.class.default[:from]),
        subject: @subject
      )
    end

    def mail_external_link(data_link, url, instructions_url = nil, receiver_attributes = {})
      @instructions_url = instructions_url
      @data_link = data_link
      @user = @data_link.creator
      @receiver = @data_link.receiver
      @receiver.attributes = receiver_attributes
      @resource = @receiver
      @locale = @data_link.locale.presence || @receiver.ui_locale
      @title = data_link_item_title
      @url = url

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

      mail(
        to: @receiver.email,
        cc: @user.email,
        bcc: DataCycleCore.data_link_bcc,
        from: t('data_link_mailer.from', from: self.class.default[:from], locale: @locale, default: self.class.default[:from]),
        subject: t('data_link_mailer.update_subject', locale: @locale)
      )
    end

    private

    def data_link_item_title
      if @data_link.item.is_a?(DataCycleCore::WatchList) || @data_link.item.is_a?(DataCycleCore::StoredFilter)
        @title = @data_link.item.try(:name)
      elsif @data_link.item.is_a?(DataCycleCore::Thing)
        I18n.with_locale(@data_link.item.first_available_locale) do
          @title = @data_link.item.try(:title)
        end
      end
    end
  end
end
