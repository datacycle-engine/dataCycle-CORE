# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Utility
    module ContentScore
      module Virtual
        class ByPresence < DataCycleCore::TestCases::ActiveSupportTestCase
          before(:all) do
            @content = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: { name: 'TestBild 1', copyright_notice_override: 'Test CopyRight' })
          end

          test 'by_presence works with virtual strings' do
            key = 'copyright_notice'

            assert_equal 1, DataCycleCore::Utility::ContentScore::Virtual.by_presence(key: key, content: @content)

            @content.set_data_hash(data_hash: { copyright_notice_override: 'T' })
            assert_equal 1, DataCycleCore::Utility::ContentScore::Virtual.by_presence(key: key, content: @content)

            @content.set_data_hash(data_hash: { copyright_notice_override: '' })
            assert_equal 0, DataCycleCore::Utility::ContentScore::Virtual.by_presence(key: key, content: @content)

            @content.set_data_hash(data_hash: { copyright_notice_override: nil })
            assert_equal 0, DataCycleCore::Utility::ContentScore::Virtual.by_presence(key: key, content: @content)
          end
        end
      end
    end
  end
end
