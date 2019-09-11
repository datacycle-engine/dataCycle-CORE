# frozen_string_literal: true

module DataCycleCore
  class DataLinkMailer < ApplicationMailer
    def mail_link(data_link, url)
      @data_link = data_link
      @user = data_link.creator
      @receiver = data_link.receiver

      if data_link.item.is_a?(DataCycleCore::WatchList)
        @title = data_link.item.try(:name)
      elsif data_link.item.class.table_name == 'things'
        I18n.with_locale(data_link.item.first_available_locale) do
          @title = data_link.item.try(:title)
        end
      end
      @url = url

      logo_file_path = Rails.root.join('app', 'assets', 'images', DataCycleCore.logo['inverted'])
      logo_file_path = DataCycleCore::Engine.root.join('app', 'assets', 'images', DataCycleCore.logo['inverted']) unless File.exist?(logo_file_path)
      attachments.inline[DataCycleCore.logo['inverted']] = File.read(logo_file_path)
      mail(to: @receiver.email, cc: @user.email, subject: 'Geteilter Link zu einem Inhalt')
    end

    def updated_items(data_link)
      return unless data_link.item.is_a?(DataCycleCore::WatchList)

      @data_link = data_link
      @user = data_link.creator
      @receiver = data_link.receiver
      @title = data_link.item.try(:name)
      @url = data_link_url(data_link)

      logo_file_path = Rails.root.join('app', 'assets', 'images', DataCycleCore.logo['inverted'])
      logo_file_path = DataCycleCore::Engine.root.join('app', 'assets', 'images', DataCycleCore.logo['inverted']) unless File.exist?(logo_file_path)
      attachments.inline[DataCycleCore.logo['inverted']] = File.read(logo_file_path)
      mail(to: @receiver.email, cc: @user.email, subject: 'Geteilte Inhaltssammlung wurde aktualisiert')
    end
  end
end
