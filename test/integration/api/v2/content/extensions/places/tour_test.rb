# frozen_string_literal: true

require 'test_helper'
require 'json'

module DataCycleCore
  module Api
    module V2
      module Content
        module Extensions
          module Places
            class Tour < DataCycleCore::TestCases::ActionDispatchIntegrationTest
              before(:all) do
                DataCycleCore::Thing.delete_all
                @content = DataCycleCore::DummyDataHelper.create_data('tour')
              end

              setup do
                sign_in(User.find_by(email: 'tester@datacycle.at'))
              end

              test 'json of stored item exists and is correct' do
                get api_v2_thing_path(id: @content)

                assert_response(:success)
                assert_equal('application/json; charset=utf-8', response.content_type)
                json_data = JSON.parse(response.body)

                # validate header
                assert_equal('http://schema.org', json_data.dig('@context'))
                assert_equal('Place', json_data.dig('@type'))
                assert_equal('Tour', json_data.dig('contentType'))
                assert_equal(root_url[0...-1] + api_v2_thing_path(id: @content), json_data.dig('@id'))
                assert_equal(@content.id, json_data.dig('identifier'))
                assert_equal(@content.created_at.as_json, json_data.dig('dateCreated'))
                assert_equal(@content.updated_at.as_json, json_data.dig('dateModified'))
                assert_equal(root_url[0...-1] + thing_path(@content), json_data.dig('url'))

                # classifications
                assert(json_data.dig('classifications').present?)
                assert_equal(1, json_data.dig('classifications').size)
                classification_hash = json_data.dig('classifications').first
                assert_equal(['id', 'name', 'createdAt', 'updatedAt', 'ancestors'].sort, classification_hash.keys.sort)
                assert_equal('Tour', classification_hash.dig('name'))
                assert_equal(2, classification_hash.dig('ancestors').size)
                assert_equal(['Inhaltstypen', 'Ort'], classification_hash.dig('ancestors').map { |item| item.dig('name') }.sort)

                # language
                assert_equal('de', json_data.dig('inLanguage'))

                # content
                assert_equal(@content.name, json_data.dig('name'))
                assert_equal(@content.description, json_data.dig('description'))
                assert_equal([6], json_data.dig('schedule').first.dig('byMonth'))

                # TODO: check image rendering via minimal or linked
                assert_equal(@content.image.first.id, json_data.dig('image').first.dig('identifier'))
                assert_equal(@content.primary_image.first.id, json_data.dig('primaryImage').first.dig('identifier'))
                assert_equal(@content.logo.first.id, json_data.dig('logo').first.dig('identifier'))
              end

              test 'stored item can be found via different endpoints' do
                get(api_v2_things_path)
                assert_response(:success)
                assert_equal('application/json; charset=utf-8', response.content_type)
                json_data = JSON.parse(response.body).dig('data').detect { |item| item.dig('@type') == 'Place' }
                assert_equal(@content.id, json_data.dig('identifier'))

                get(api_v2_contents_search_path)
                assert_response(:success)
                assert_equal('application/json; charset=utf-8', response.content_type)
                json_data = JSON.parse(response.body).dig('data').detect { |item| item.dig('@type') == 'Place' }
                assert_equal(@content.id, json_data.dig('identifier'))

                get(api_v2_places_path)
                assert_response(:success)
                assert_equal('application/json; charset=utf-8', response.content_type)
                json_data = JSON.parse(response.body).dig('data').first
                assert_equal(@content.id, json_data.dig('identifier'))
              end
            end
          end
        end
      end
    end
  end
end
