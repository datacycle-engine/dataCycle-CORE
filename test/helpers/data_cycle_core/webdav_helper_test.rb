# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class WebdavHelperTest < ActionView::TestCase
    include DataCycleCore::WebdavHelper

    test 'parse_request returns all allowed props for an allprop request' do
      assert_equal DataCycleCore::WebdavHelper::ALLOWED_PROPS, parse_request('<propfind><allprop/></propfind>')
    end

    test 'parse_request returns all allowed props for a blank body' do
      assert_equal DataCycleCore::WebdavHelper::ALLOWED_PROPS, parse_request('')
    end

    test 'parse_request returns only the requested allowed props and drops unknown ones' do
      body = '<propfind><prop><displayname/><getcontentlength/><madeupprop/></prop></propfind>'

      assert_equal ['displayname', 'getcontentlength'], parse_request(body)
    end

    test 'parse_request returns an empty array when no prop element is present' do
      assert_equal [], parse_request('<propfind><other/></propfind>')
    end

    test 'parse_request returns an empty array for an empty prop element' do
      assert_equal [], parse_request('<propfind><prop></prop></propfind>')
    end

    test 'get_ext extracts the file extension with a leading dot' do
      assert_equal '.txt', get_ext('document.txt')
      assert_equal '.gz', get_ext('archive.tar.gz')
    end

    test 'get_ext returns nil for blank input' do
      assert_nil get_ext('')
      assert_nil get_ext(nil)
    end

    test 'parse_header keeps only HTTP_ headers and strips the prefix' do
      request = struct_double(env: { 'HTTP_FOO' => 'bar', 'HTTP_BAZ' => 'qux', 'REQUEST_METHOD' => 'PROPFIND' })

      assert_equal({ 'FOO' => 'bar', 'BAZ' => 'qux' }, parse_header(request))
    end

    test 'parse_header returns nil when there are no HTTP_ headers' do
      assert_nil parse_header(struct_double(env: { 'REQUEST_METHOD' => 'GET' }))
    end
  end
end
