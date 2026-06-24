# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class ContentHelperTest < ActionView::TestCase
    include DataCycleCore::ContentHelper

    test 'generate_uuid keeps the prefix and rewrites the last segment deterministically' do
      id = 'aaaaaaaa-bbbb-cccc-dddd-000000000001'

      assert_equal 'aaaaaaaa-bbbb-cccc-dddd-78805a221a99', generate_uuid(id, 'image')
      assert_equal 'aaaaaaaa-bbbb-cccc-dddd-951d4dff3c23', generate_uuid(id, 'thumbnail')
    end

    test 'generate_uuid is stable for identical input and varies by key' do
      id = 'aaaaaaaa-bbbb-cccc-dddd-000000000001'

      assert_equal generate_uuid(id, 'image'), generate_uuid(id, 'image')
      assert_not_equal generate_uuid(id, 'image'), generate_uuid(id, 'thumbnail')
    end

    test 'aspect_ratio returns a css rule for positive dimensions' do
      assert_equal 'aspect-ratio: 89/50;', aspect_ratio(struct_double(width: 1920, height: 1080))
    end

    test 'aspect_ratio returns nil for missing or non-positive dimensions' do
      assert_nil aspect_ratio(struct_double(width: nil, height: 1080))
      assert_nil aspect_ratio(struct_double(width: 0, height: 1080))
      assert_nil aspect_ratio(Object.new)
    end

    test 'image_thumb_style is landscape when wider than tall' do
      assert_equal 'aspect-ratio: 89/50; width: 100%; max-width: 1920.0px;', image_thumb_style(struct_double(width: 1920, height: 1080))
    end

    test 'image_thumb_style is portrait when taller than wide' do
      assert_equal 'aspect-ratio: 14/25; height: 100%; max-height: 1920.0px;', image_thumb_style(struct_double(width: 1080, height: 1920))
    end

    test 'image_thumb_style returns nil for invalid dimensions' do
      assert_nil image_thumb_style(struct_double(width: 0, height: 0))
      assert_nil image_thumb_style(Object.new)
    end

    test 'thing_thumbnail_url prefers the virtual attribute' do
      content = struct_double(virtual_thumbnail_url: 'virtual.jpg', thumbnail_url: 'real.jpg')

      assert_equal 'virtual.jpg', thing_thumbnail_url(content)
    end

    test 'thing_thumbnail_url falls back to the plain attribute' do
      assert_equal 'real.jpg', thing_thumbnail_url(struct_double(thumbnail_url: 'real.jpg'))
    end

    test 'thing_thumbnail_url resolves the value from a linked attribute first' do
      content = struct_double(asset: struct_double(thumbnail_url: 'linked.jpg'), thumbnail_url: 'own.jpg')

      assert_equal 'linked.jpg', thing_thumbnail_url(content, :asset)
    end

    test 'thing_asset_web_url resolves the web_url attribute' do
      assert_equal 'web.jpg', thing_asset_web_url(struct_double(web_url: 'web.jpg'))
    end

    test 'thing_thumbnail_url returns nil when no attribute is present' do
      assert_nil thing_thumbnail_url(Object.new)
    end
  end
end
