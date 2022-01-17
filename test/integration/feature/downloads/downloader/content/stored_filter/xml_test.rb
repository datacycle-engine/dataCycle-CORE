# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Feature
    module Downloads
      module Downloader
        module Content
          module StoredFilter
            class XmlTest < DataCycleCore::TestCases::ActionDispatchIntegrationTest
              before(:all) do
                @routes = Engine.routes
                @current_user = User.find_by(email: 'tester@datacycle.at')
                @content = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'Article Test' })
                @stored_filter = DataCycleCore::StoredFilter.create(
                  name: 'TestFilter',
                  user_id: @current_user.id,
                  language: ['de'],
                  parameters: [],
                  api: true
                )
                @serialize_config = DataCycleCore.features[:serialize].deep_dup
                @download_config = DataCycleCore.features[:download].deep_dup
              end

              setup do
                sign_in(@current_user)
              end

              test 'check if xml serializer is disabled for stored_filters' do
                assert_not DataCycleCore.features.dig(:serialize, :serializers, :xml)
                assert_not DataCycleCore.features.dig(:download, :downloader, :content, :stored_filter, :enabled)
                assert_not DataCycleCore.features.dig(:download, :downloader, :content, :stored_filter, :serializers, :xml)
                assert_not DataCycleCore::Feature::Download.allowed?(@stored_filter)

                get download_stored_filter_path(@stored_filter), params: { serialize_format: 'xml' }, headers: {
                  referer: stored_filter_path(@stored_filter)
                }

                assert_equal(302, response.status)
              end

              test 'enable stored_filter xml serializer and render xml download for stored_filter' do
                DataCycleCore.features[:serialize][:serializers][:xml] = true
                DataCycleCore.features[:download][:downloader][:content][:stored_filter][:enabled] = true
                DataCycleCore.features[:download][:downloader][:content][:stored_filter][:serializers][:xml] = true
                assert DataCycleCore::Feature::Download.allowed?(@stored_filter)

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
                DataCycleCore.features[:download][:downloader][:content][:stored_filter][:enabled] = true
                DataCycleCore.features[:download][:downloader][:content][:stored_filter][:serializers][:xml] = true
                assert DataCycleCore::Feature::Download.allowed?(@stored_filter)

                get "/downloads/stored_filters/#{@stored_filter.id}", params: { serialize_format: 'xml' }, headers: {
                  referer: stored_filter_path(@stored_filter)
                }

                assert_response :success
                xml = Nokogiri::XML(response.body)
                assert xml.errors.blank?
                assert_equal @content.name, xml.xpath('//thing/name').text
              end

              def teardown
                DataCycleCore.features[:serialize][:serializers] = @serialize_config[:serializers].deep_dup
                DataCycleCore.features[:download][:downloader] = @download_config[:downloader].deep_dup
                DataCycleCore::Feature::Serialize.reload
                DataCycleCore::Feature::Download.reload
              end
            end
          end
        end
      end
    end
  end
end
