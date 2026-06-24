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
  end
end
