# frozen_string_literal: true

module DataCycleCore
  class DataLinkMailer < ApplicationMailer
    def mail_link(data_link, url)
      @data_link ||= data_link
      @user ||= @data_link.creator
      @receiver ||= @data_link.receiver
      @locale ||= @data_link.locale.presence || @receiver.ui_locale
      @title ||= data_link_item_title
      @url ||= url
      @subject ||= first_available_i18n_t("data_link_mailer.#{@current_issuer}.send_subject", @current_issuer, { title: @title, locale: @locale })

      mail(
        to: @receiver.email,
        cc: @user.email,
        from: t('data_link_mailer.from', from: self.class.default[:from], locale: @locale, default: self.class.default[:from]),
        subject: @subject
      )
    end

    def mail_external_link(data_link, url, instructions_url = nil, webhook_source = nil)
      @instructions_url = instructions_url
      @data_link = data_link
      @current_issuer = webhook_source
      @user = @data_link.creator
      @receiver = @data_link.receiver
      @resource = @receiver
      @resource.mailer_layout = "data_cycle_core/#{@current_issuer}_mailer" if @current_issuer.present? && lookup_context.exists?("data_cycle_core/#{@current_issuer}_mailer", ['layouts'], false, [], formats: [:html])
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
