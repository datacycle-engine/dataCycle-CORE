# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Utility
    module Compute
      class AssetTest < DataCycleCore::TestCases::ActiveSupportTestCase
        def subject
          DataCycleCore::Utility::Compute::Asset
        end

        test 'file_name returns the asset name as a string' do
          DataCycleCore::Asset.stub(:find_by, struct_double(name: 'photo.jpg')) do
            assert_equal('photo.jpg', subject.file_name(computed_parameters: { 'asset' => 'asset-id' }))
          end
        end

        test 'content_url_from_slug uses the parameter slug for the primary locale' do
          content = Class.new { def first_available_locale(_ = nil) = I18n.locale }.new

          DataCycleCore::Asset.stub(:find_by, struct_double(file_extension: 'jpg')) do
            value = subject.content_url_from_slug(content:, computed_parameters: { 'asset' => 'asset-id', 'slug' => 'my-slug' })

            assert_includes(value, 'my-slug.jpg')
          end
        end

        test 'content_url_from_slug falls back to the content slug for a non-primary locale' do
          content = Class.new {
            define_method(:first_available_locale) { |_ = nil| (I18n.available_locales - [I18n.locale]).first }
            def slug = 'content-slug'
          }.new

          DataCycleCore::Asset.stub(:find_by, struct_double(file_extension: 'png')) do
            value = subject.content_url_from_slug(content:, computed_parameters: { 'asset' => 'asset-id', 'slug' => 'param-slug' })

            assert_includes(value, 'content-slug.png')
          end
        end

        test 'content_url_from_slug returns nil when the asset is missing' do
          DataCycleCore::Asset.stub(:find_by, nil) do
            assert_nil(subject.content_url_from_slug(content: Object.new, computed_parameters: { 'asset' => 'missing' }))
          end
        end

        test 'asset_url_with_transformation returns the dynamic variant url' do
          asset = Class.new {
            def dynamic(_transformation) = Struct.new(:url).new('https://dyn.test/img.jpg')
          }.new

          DataCycleCore::Asset.stub(:find_by, asset) do
            value = subject.asset_url_with_transformation(
              computed_parameters: { 'asset' => 'asset-id' },
              computed_definition: { 'compute' => { 'transformation' => { 'version' => 'thumb' } } }
            )

            assert_equal('https://dyn.test/img.jpg', value)
          end
        end

        test 'imgproxy_url returns the cached value when no parameter changed' do
          content = Class.new {
            def attribute_to_h(_key) = 'unchanged'
            def imgproxy = 'https://cdn.test/cached.jpg'
          }.new

          value = subject.imgproxy_url(
            content:,
            key: 'imgproxy',
            computed_parameters: { 'asset' => 'unchanged' },
            computed_definition: { 'compute' => {} }
          )

          assert_equal('https://cdn.test/cached.jpg', value)
        end

        test 'imgproxy_url processes the image through the imgproxy feature when a parameter changed' do
          recorded = {}
          thing = Object.new
          thing.define_singleton_method(:id=) { |v| recorded[:id] = v }
          thing.define_singleton_method(:cache_valid_since=) { |v| recorded[:cache_valid_since] = v }
          thing.define_singleton_method(:set_memoized_attribute) { |k, v| recorded[k] = v }

          template = Struct.new(:template_thing).new(thing)
          content = Object.new
          content.define_singleton_method(:attribute_to_h) { |_key| 'persisted' }
          content.define_singleton_method(:thing_template) { template }
          content.define_singleton_method(:id) { 'content-id' }
          content.define_singleton_method(:cache_valid_since) { nil }

          DataCycleCore::Feature::GravityEditor.stub(:allowed?, false) do
            DataCycleCore::Feature::FocusPointEditor.stub(:allowed?, false) do
              DataCycleCore::Feature::ImageProxy.stub(:process_image, 'https://imgproxy.test/result.jpg') do
                value = subject.imgproxy_url(
                  content:,
                  key: 'imgproxy',
                  computed_parameters: { 'asset' => 'new-asset' },
                  computed_definition: { 'compute' => { 'transformation' => { 'version' => 'v1' }, 'processing' => { 'quality' => 80 } } }
                )

                assert_equal('https://imgproxy.test/result.jpg', value)
              end
            end
          end

          assert_equal('content-id', recorded[:id])
          assert_equal('new-asset', recorded['asset'])
        end

        test 'etag returns the response etag on a 200 response' do
          response = Struct.new(:status) { def [](_key) = 'etag-200' }.new(200)
          content = struct_double(etag: 'old-etag')

          Faraday.stub(:default_connection, faraday_connection(response)) do
            value = subject.etag(content:, computed_parameters: { 'content_url' => 'https://cdn.test/img.jpg' })

            assert_equal('etag-200', value)
          end
        end

        test 'etag returns nil on a non-200 response' do
          response = Struct.new(:status) { def [](_key) = 'etag-304' }.new(304)
          content = struct_double(etag: 'old-etag')

          Faraday.stub(:default_connection, faraday_connection(response)) do
            assert_nil(subject.etag(content:, computed_parameters: { 'content_url' => 'https://cdn.test/img.jpg' }))
          end
        end

        test 'etag returns nil when the request raises' do
          conn = Object.new
          conn.define_singleton_method(:head) { |*_args, &_block| raise Faraday::ConnectionFailed, 'boom' }
          content = struct_double(etag: 'old-etag')

          Faraday.stub(:default_connection, conn) do
            assert_nil(subject.etag(content:, computed_parameters: { 'content_url' => 'https://cdn.test/img.jpg' }))
          end
        end

        private

        def faraday_connection(response)
          conn = Object.new
          conn.define_singleton_method(:head) do |_url, &block|
            block&.call(Struct.new(:headers).new({}))
            response
          end
          conn
        end
      end
    end
  end
end
