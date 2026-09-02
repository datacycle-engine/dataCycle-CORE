# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'

module DataCycleCore
  module Content
    module Attributes
      class OembedTest < DataCycleCore::TestCases::ActiveSupportTestCase
        test 'create oembed with data' do
          with_test_oembed_provider do
            url = TEST_OEMBED_URL

            content = DataCycleCore::TestPreparations.create_content(
              template_name: 'OEmbed',
              data_hash: {
                name: 'Oembed',
                url:
              }
            )

            assert_equal url, content.url

            url2 = "#{TEST_OEMBED_PROVIDER_URL}/watch?v=2"

            content.set_data_hash(data_hash: {
              url: url2
            })

            assert_equal url2, content.url
          end
        end
      end
    end
  end
end
