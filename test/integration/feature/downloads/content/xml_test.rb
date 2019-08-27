# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Feature
    module Downloads
      module Content
        class XmlTest < ActionDispatch::IntegrationTest
          include Devise::Test::IntegrationHelpers
          include Engine.routes.url_helpers

          setup do
            @routes = Engine.routes
            @content = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'Article Test' })
            sign_in(User.find_by(email: 'tester@datacycle.at'))
          end

          test 'check if xml serializer is disabled' do
            xml_serializer_setting = DataCycleCore.features.dig(:serialize, :serializers, :xml)
            assert_not xml_serializer_setting

            get download_thing_path(@content), params: { serialize_format: 'xml' }, headers: {
              referer: thing_path(@content)
            }

            assert_equal(302, response.status)
          end

          test 'enable xml serializer and render xml download for article' do
            DataCycleCore.features[:serialize][:serializers][:xml] = true

            get download_thing_path(@content), params: { serialize_format: 'xml' }, headers: {
              referer: thing_path(@content)
            }

            assert_response :success
            assert response.body.include?(@content.name)
            xml = Nokogiri::XML(response.body)
            assert xml.errors.blank?
            assert_equal @content.name, xml.xpath('//schema:thing/schema:name').text
          end

          test 'enable xml serializer and test downloads controller' do
            DataCycleCore.features[:serialize][:serializers][:xml] = true

            get "/downloads/things/#{@content.id}", params: { serialize_format: 'xml' }, headers: {
              referer: thing_path(@content)
            }

            assert_response :success
            assert response.body.include?(@content.name)
            xml = Nokogiri::XML(response.body)
            assert xml.errors.blank?
            assert_equal @content.name, xml.xpath('//schema:thing/schema:name').text
          end

          def teardown
            DataCycleCore.features[:serialize][:serializers][:xml] = false
          end
        end
      end
    end
  end
end
