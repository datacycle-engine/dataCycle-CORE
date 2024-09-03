# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'

module DataCycleCore
  module Content
    module Attributes
      class OembedTest < DataCycleCore::TestCases::ActiveSupportTestCase
        test 'create oembed with data' do
          url = 'https://vimeo.com/226053498'

          content = DataCycleCore::TestPreparations.create_content(
            template_name: 'OEmbed',
            data_hash: {
              name: 'Oembed',
              url:
            }
          )

          assert_equal url, content.url

          url2 = 'https://www.youtube.com/watch?v=AlGcVkVzxt0&t=1s&pp=ygUJZGF0YWN5Y2xl'

          content.set_data_hash(data_hash: {
            url: url2
          })

          assert_equal url2, content.url
        end
      end
    end
  end
end
