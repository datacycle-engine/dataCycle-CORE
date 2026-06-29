# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Utility
    module Virtual
      class AssetTest < DataCycleCore::TestCases::ActiveSupportTestCase
        def subject
          DataCycleCore::Utility::Virtual::Asset
        end

        test 'proxy_url for the original version uses the linked asset file extension' do
          content = struct_double(name: 'My Asset', id: 'aid-1', asset: struct_double(file: struct_double(url: 'http://x/orig.jpg')), content_url: 'http://x/content.png')
          definition = { 'virtual' => { 'transformation' => { 'version' => 'original' } } }

          value = subject.proxy_url(virtual_definition: definition, content:)

          assert_includes(value, 'asset/aid-1/original/my_asset.jpg')
        end

        test 'proxy_url for the original version falls back to the content_url extension without an asset' do
          content = struct_double(name: 'My Asset', id: 'aid-2', content_url: 'http://x/content.png')
          definition = { 'virtual' => { 'transformation' => { 'version' => 'original' } } }

          value = subject.proxy_url(virtual_definition: definition, content:)

          assert_includes(value, 'asset/aid-2/original/my_asset.png')
        end

        test 'proxy_url for the dynamic version encodes type, width and height' do
          content = struct_double(name: 'My Asset', id: 'aid-3')
          definition = { 'virtual' => { 'transformation' => { 'version' => 'dynamic', 'type' => 'fill', 'width' => '300', 'height' => '200', 'format' => 'webp' } } }

          value = subject.proxy_url(virtual_definition: definition, content:)

          assert_includes(value, 'asset/aid-3/fill/300/200/my_asset.webp')
        end

        test 'proxy_url for a static version encodes version and format' do
          content = struct_double(name: 'My Asset', id: 'aid-4')
          definition = { 'virtual' => { 'transformation' => { 'version' => 'thumb', 'format' => 'jpg' } } }

          value = subject.proxy_url(virtual_definition: definition, content:)

          assert_includes(value, 'asset/aid-4/thumb/my_asset.jpg')
        end

        test 'name returns the name of the linked asset' do
          content = struct_double(asset: struct_double(name: 'Asset Name'))

          assert_equal('Asset Name', subject.name(content:, virtual_parameters: ['asset']))
        end

        test 'asset_id returns the id of the linked asset' do
          content = struct_double(asset: struct_double(id: 'asset-id-1'))

          assert_equal('asset-id-1', subject.asset_id(content:))
        end

        test 'transform_gravity! resolves the gravity from a matching classification uri' do
          content = struct_double(classification_property_names: ['focus'], focus: [struct_double(uri: 'https://schema.test/focus#center')])
          image_processing = { 'gravity' => ['focus'] }

          result = subject.send(:transform_gravity!, content, image_processing)

          assert_equal('center', result['gravity'])
        end
      end
    end
  end
end
