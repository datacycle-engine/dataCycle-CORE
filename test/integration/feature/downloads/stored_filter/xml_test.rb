# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Feature
    module Downloads
      module StoredFilter
        class XmlTest < ActionDispatch::IntegrationTest
          include Devise::Test::IntegrationHelpers
          include Engine.routes.url_helpers

          setup do
            @routes = Engine.routes

            @content = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'Article Test' })
            sign_in(User.find_by(email: 'tester@datacycle.at'))

            post(
              stored_filters_path,
              params: { stored_filter: { name: 'TestFilter' } },
              headers: { referer: root_path }
            )
            @stored_filter = User.find_by(email: 'tester@datacycle.at').stored_filters.presence&.find_by(name: 'TestFilter')
            @stored_filter.update(api: true)
          end

          test 'check if xml serializer is disabled for stored_filters' do
            assert_not DataCycleCore.features.dig(:download, :collections, :stored_filter, :enabled)

            get download_stored_filter_path(@stored_filter), params: { serialize_format: 'xml' }, headers: {
              referer: stored_filter_path(@stored_filter)
            }

            assert_equal(302, response.status)
          end

          test 'enable stored_filter xml serializer and render xml download for stored_filter' do
            DataCycleCore.features[:serialize][:serializers][:xml] = true
            DataCycleCore.features[:download][:collections][:stored_filter][:enabled] = true
            DataCycleCore.features[:download][:collections][:stored_filter][:serializers][:xml] = true

            get download_stored_filter_path(@stored_filter), params: { serialize_format: 'xml' }, headers: {
              referer: stored_filter_path(@stored_filter)
            }

            assert_response :success
            xml = Nokogiri::XML(response.body)
            assert xml.errors.blank?
            assert_equal @content.name, xml.xpath('//thing/name').text
          end

          test 'enable stored_filter xml serializer and test downloads controller' do
            DataCycleCore.features[:serialize][:serializers][:xml] = true
            DataCycleCore.features[:download][:collections][:stored_filter][:enabled] = true
            DataCycleCore.features[:download][:collections][:stored_filter][:serializers][:xml] = true

            get "/downloads/stored_filters/#{@stored_filter.id}", params: { serialize_format: 'xml' }, headers: {
              referer: stored_filter_path(@stored_filter)
            }

            assert_response :success
            xml = Nokogiri::XML(response.body)
            assert xml.errors.blank?
            assert_equal @content.name, xml.xpath('//thing/name').text
          end

          def teardown
            DataCycleCore.features[:serialize][:serializers][:xml] = false
            DataCycleCore.features[:download][:collections][:stored_filter][:enabled] = false
            DataCycleCore.features[:download][:collections][:stored_filter][:serializers][:xml] = false
          end
        end
      end
    end
  end
end
