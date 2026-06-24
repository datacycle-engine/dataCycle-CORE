# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class CssInlinerTest < DataCycleCore::TestCases::ActiveSupportTestCase
    HTML = '<html><head><style>p { color: red; }</style></head><body><p>hello</p></body></html>'

    test 'delivering_email inlines styles for a non multipart message' do
      message = Mail.new
      message.content_type = 'text/html; charset=UTF-8'
      message.body = HTML

      result = DataCycleCore::CssInliner.delivering_email(message)

      assert_same message, result
      assert_includes result.body.decoded, 'color: red'
    end

    test 'delivering_email inlines styles for the html part of a multipart message' do
      message = Mail.new
      message.text_part = Mail::Part.new { body 'hello' }
      message.html_part = Mail::Part.new do
        content_type 'text/html; charset=UTF-8'
        body HTML
      end

      result = DataCycleCore::CssInliner.delivering_email(message)

      assert_predicate result, :multipart?
      assert_includes result.html_part.body.decoded, 'color: red'
    end
  end
end
