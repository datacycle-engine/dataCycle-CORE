# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class DataLinkMailerTest < DataCycleCore::TestCases::ActiveSupportTestCase
    before(:all) do
      @creator = DataCycleCore::User.find_by(email: 'admin@datacycle.at')
      @receiver = DataCycleCore::User.find_by(email: 'guest@datacycle.at')
      @watch_list = DataCycleCore::WatchList.create!(full_path: 'DataLinkMailerWatchList', user: @creator)
      @content = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'DataLinkMailerArticle' })
      @data_link = DataCycleCore::DataLink.create!(
        item: @watch_list,
        creator: @creator,
        receiver: @receiver,
        permissions: 'read',
        locale: 'de'
      )
      @thing_data_link = DataCycleCore::DataLink.create!(
        item: @content,
        creator: @creator,
        receiver: @receiver,
        permissions: 'read',
        locale: 'de'
      )
    end

    test 'mail_link builds a data link mail to the receiver' do
      mail = DataCycleCore::DataLinkMailer.mail_link(@data_link, 'https://example.com/link')

      assert_equal [@receiver.email], mail.to
      assert_includes mail.cc, @creator.email
      assert_predicate mail.subject, :present?
    end

    test 'mail_external_link builds a mail via mail_link' do
      mail = DataCycleCore::DataLinkMailer.mail_external_link(@data_link, 'https://example.com/link', 'https://example.com/help', {})

      assert_equal [@receiver.email], mail.to
      assert_predicate mail.subject, :present?
    end

    test 'mail_link derives the title from a thing item' do
      mail = DataCycleCore::DataLinkMailer.mail_link(@thing_data_link, 'https://example.com/link')

      assert_equal [@receiver.email], mail.to
      assert_predicate mail.subject, :present?
    end

    test 'updated_items builds a mail for a watch list data link' do
      mail = DataCycleCore::DataLinkMailer.updated_items(@data_link)

      assert_equal [@receiver.email], mail.to
      assert_predicate mail.subject, :present?
    end
  end
end
