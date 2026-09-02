# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class AssetPathHelperTest < ActionView::TestCase
    include DataCycleCore::AssetPathHelper

    test 'dc_image_path returns nil for a blank filename' do
      assert_nil dc_image_path('')
      assert_nil dc_image_path(nil)
    end

    test 'dc_image_url returns nil for a blank filename' do
      assert_nil dc_image_url('')
      assert_nil dc_image_url(nil)
    end

    test 'dc_vite_asset_url returns nil for a blank asset path' do
      assert_nil dc_vite_asset_url('')
      assert_nil dc_vite_asset_url(nil)
    end

    test 'dc_background_image_style returns nil when no background images are configured' do
      DataCycleCore.stub(:logo, {}) do
        assert_nil dc_background_image_style
      end
    end

    test 'dc_background_image_style defaults the background position to center center' do
      DataCycleCore.stub(:logo, { 'background_images' => ['dc-bg.png'] }) do
        stub(:dc_image_path, '/images/dc-bg.png') do
          style = dc_background_image_style

          assert_includes style, "--dc-background-image-url: url('/images/dc-bg.png');"
          assert_includes style, '--dc-background-image-position: center center;'
        end
      end
    end

    test 'dc_background_image_style uses the configured background position' do
      DataCycleCore.stub(:logo, { 'background_images' => ['dc-bg.png'], 'background_position' => 'center bottom' }) do
        stub(:dc_image_path, '/images/dc-bg.png') do
          assert_includes dc_background_image_style, '--dc-background-image-position: center bottom;'
        end
      end
    end
  end
end
