# frozen_string_literal: true

require 'test_helper'
require 'json'

module DataCycleCore
  module Api
    module V3
      module Content
        module Extensions
          module CreativeWorks
            class Video < DataCycleCore::TestCases::ActionDispatchIntegrationTest
              before(:all) do
                DataCycleCore::Thing.where(template: false).delete_all
                @content = DataCycleCore::DummyDataHelper.create_data('video')
              end

              setup do
                sign_in(User.find_by(email: 'tester@datacycle.at'))
              end

              test 'json of stored image exists and is correct' do
                get api_v3_thing_path(id: @content)

                assert_response(:success)
                assert_equal('application/json; charset=utf-8', response.content_type)
                json_data = JSON.parse(response.body)

                # validate header
                assert_equal('http://schema.org', json_data.dig('@context'))
                assert_equal('VideoObject', json_data.dig('@type').last)
                assert_equal('Video', json_data.dig('contentType'))
                assert_equal(root_url[0...-1] + api_v3_thing_path(id: @content), json_data.dig('@id'))
                assert_equal(@content.id, json_data.dig('identifier'))
                assert_equal(@content.created_at.as_json, json_data.dig('dateCreated'))
                assert_equal(@content.updated_at.as_json, json_data.dig('dateModified'))
                assert_equal(root_url[0...-1] + thing_path(@content), json_data.dig('url'))

                # validity period
                # TODO: (move to generic tests)

                # classifications
                # TODO: (move to generic tests)
                assert(json_data.dig('classifications').present?)
                assert_equal(1, json_data.dig('classifications').size)
                classification_hash = json_data.dig('classifications').first
                assert_equal(['id', 'name', 'createdAt', 'updatedAt', 'ancestors'].sort, classification_hash.keys.sort)
                assert_equal('Video', classification_hash.dig('name'))
                assert_equal(2, classification_hash.dig('ancestors').size)
                assert_equal(['Asset', 'Inhaltstypen'], classification_hash.dig('ancestors').map { |item| item.dig('name') }.sort)

                # language
                assert_equal('de', json_data.dig('inLanguage'))

                # content data
                assert_equal(@content.name, json_data.dig('headline'))
                assert_equal(@content.caption, json_data.dig('caption'))
                assert_equal(@content.description, json_data.dig('description'))
                assert_equal(@content.url, json_data.dig('sameAs'))
                assert_equal(@content.content_url, json_data.dig('contentUrl'))
                if json_data.dig('thumbnailUrl').present?
                  assert_equal(@content.thumbnail_url, json_data.dig('thumbnailUrl'))
                else
                  assert_nil(@content.thumbnail_url)
                end
                assert_equal(@content.content_size, json_data.dig('contentSize'))
                assert_equal(@content.file_format, json_data.dig('fileFormat'))
                assert_equal(@content.video_frame_size, json_data.dig('videoFrameSize'))
                assert_equal(@content.video_quality, json_data.dig('videoQuality'))
                assert_equal("PT#{@content.duration}S", json_data.dig('duration'))

                # TODO: (move to Transformations tests)
                # API: Transformation: QuantitativeValue
                assert_equal(@content.width, json_data.dig('width', 'value'))
                assert_equal(@content.height, json_data.dig('height', 'value'))
              end

              test 'stored item can be found via different endpoints' do
                get(api_v3_things_path)
                assert_response(:success)
                assert_equal('application/json; charset=utf-8', response.content_type)
                json_data = JSON.parse(response.body).dig('data').first
                assert_equal(@content.id, json_data.dig('identifier'))

                get(api_v3_contents_search_path)
                assert_response(:success)
                assert_equal('application/json; charset=utf-8', response.content_type)
                json_data = JSON.parse(response.body).dig('data').first
                assert_equal(@content.id, json_data.dig('identifier'))

                get(api_v3_creative_works_path)
                assert_response(:success)
                assert_equal('application/json; charset=utf-8', response.content_type)
                json_data = JSON.parse(response.body).dig('data').first
                assert_equal(@content.id, json_data.dig('identifier'))
              end

              test 'APIv2 json equals APIv3 json result' do
                get api_v2_thing_path(id: @content)
                assert_response(:success)
                assert_equal('application/json; charset=utf-8', response.content_type)
                api_v2_json = JSON.parse(response.body)

                get api_v3_thing_path(id: @content)
                assert_response(:success)
                assert_equal('application/json; charset=utf-8', response.content_type)
                api_v3_json = JSON.parse(response.body)

                excepted_params = ['@id']

                assert_equal(api_v3_json.except(*excepted_params), api_v2_json.except(*excepted_params))
              end
            end
          end
        end
      end
    end
  end
end
