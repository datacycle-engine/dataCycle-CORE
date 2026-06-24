# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class AssetHelpersTest < ActionView::TestCase
    include DataCycleCore::AssetHelpers

    attr_accessor :thumb_preview

    test 'headline is always an empty string' do
      assert_equal '', headline
    end

    test 'thumbnail_url? is true when a thumb preview is present' do
      self.thumb_preview = struct_double(url: 'https://example.com/thumb.jpg')

      assert_predicate self, :thumbnail_url?
    end

    test 'thumbnail_url? is nil without a thumb preview' do
      self.thumb_preview = nil

      assert_nil thumbnail_url?
    end

    test 'thumbnail_url returns the preview url when present' do
      self.thumb_preview = struct_double(url: 'https://example.com/thumb.jpg')

      assert_equal 'https://example.com/thumb.jpg', thumbnail_url
    end

    test 'thumbnail_url is nil without a thumb preview' do
      self.thumb_preview = nil

      assert_nil thumbnail_url
    end
  end
end
