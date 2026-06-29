# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Generic
    module Common
      # Coverage for the Webhook base implementation: the not-implemented CRUD hooks
      # and the blank-argument guards of download_content / import_content. The
      # download/import bodies need a real external source + download/import objects
      # (pipeline) and are left to the integration suite.
      class WebhookCoverageTest < DataCycleCore::TestCases::ActiveSupportTestCase
        def webhook
          DataCycleCore::Generic::Common::Webhook.new(nil, nil, nil, nil)
        end

        test 'update, create and delete are not implemented' do
          assert_raises(NotImplementedError) { webhook.update({}, nil) }
          assert_raises(NotImplementedError) { webhook.create({}, nil) }
          assert_raises(NotImplementedError) { webhook.delete({}, nil) }
        end

        test 'download_content returns nil when an argument is blank' do
          assert_nil(webhook.download_content(download_config: nil, data_name: 'x', data: { 'a' => 1 }))
        end

        test 'import_content returns nil when an argument is blank' do
          assert_nil(webhook.import_content(import_config: nil, data_name: 'x', data: { 'a' => 1 }, locale: 'de'))
        end
      end
    end
  end
end
