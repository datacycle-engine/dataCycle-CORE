# frozen_string_literal: true

require 'test_helper'
require 'json'

module DataCycleCore
  module Api
    module V2
      class ThingTest < ActionDispatch::IntegrationTest
        include Devise::Test::IntegrationHelpers
        include Engine.routes.url_helpers

        setup do
          @routes = Engine.routes
          @content = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'TestArtikel' })
          sign_in(User.find_by(email: 'tester@datacycle.at'))
        end

        test 'json of stored article exists' do
          get api_v2_thing_path(@content)

          assert_response(:success)
          assert_equal('application/json', response.content_type)
          json_data = JSON.parse(response.body)
          assert_equal('TestArtikel', json_data['headline'])
        end

        test 'stored article can be found and is correct' do
          get(api_v2_things_path)

          assert_response(:success)
          assert_equal('application/json', response.content_type)
          json_data = JSON.parse(response.body)

          assert(json_data.dig('data').present?)
          assert_equal(1, json_data.dig('data').size)

          data_hash = json_data.dig('data').first
          assert_equal('http://schema.org', data_hash.dig('@context'))
          assert_equal('CreativeWork', data_hash.dig('@type'))
          assert_equal('Artikel', data_hash.dig('contentType'))
          assert(data_hash.dig('@id').present?)
          assert_equal(@content.id, data_hash.dig('identifier'))
          assert(data_hash.dig('url').present?)
          assert(data_hash.dig('dateCreated').present?)
          assert(data_hash.dig('dateModified').present?)
          assert_equal('de', data_hash.dig('inLanguage'))
          assert_equal('TestArtikel', data_hash.dig('headline'))

          assert(data_hash.dig('classifications').present?)
          assert_equal(1, data_hash.dig('classifications').size)
          classification_hash = data_hash.dig('classifications').first
          assert_equal(['id', 'name', 'createdAt', 'updatedAt', 'ancestors'].sort, classification_hash.keys.sort)
          assert_equal('Artikel', classification_hash.dig('name'))
          assert_equal(2, classification_hash.dig('ancestors').size)
          assert_equal(['Inhaltstypen', 'Text'], classification_hash.dig('ancestors').map { |item| item.dig('name') }.sort)

          assert(data_hash.dig('releaseStatusId').present?)
          assert_equal(1, data_hash.dig('releaseStatusId').size)
          assert_equal('freigegeben', data_hash.dig('releaseStatusId').first.dig('name'))
          assert_equal(1, data_hash.dig('releaseStatusId').first.dig('ancestors').size)
          assert_equal('Release-Stati', data_hash.dig('releaseStatusId').first.dig('ancestors').first.dig('name'))

          assert(data_hash.dig('dataPool').present?)
          assert_equal(1, data_hash.dig('dataPool').size)
          assert_equal('Aktuelle Inhalte', data_hash.dig('dataPool').first.dig('name'))
          assert_equal(1, data_hash.dig('dataPool').first.dig('ancestors').size)
          assert_equal('Inhaltspools', data_hash.dig('dataPool').first.dig('ancestors').first.dig('name'))

          assert(json_data['meta'].present?)
          assert_equal(1, json_data.dig('meta', 'total'))
          assert_equal(1, json_data.dig('meta', 'pages'))
          assert(json_data['links'].present?)
          assert(json_data.dig('links', 'self').present?)
        end

        test 'stored article can be found in different ways' do
          get(api_v2_contents_search_path)
          assert_response(:success)
          assert_equal('application/json', response.content_type)
          json_data_search = JSON.parse(response.body)

          get(api_v2_things_path)
          assert_response(:success)
          assert_equal('application/json', response.content_type)
          json_data_things = JSON.parse(response.body)

          get(api_v2_creative_works_path)
          assert_response(:success)
          assert_equal('application/json', response.content_type)
          json_data_creative_works = JSON.parse(response.body)

          assert(json_data_search != json_data_things)
          assert_equal(json_data_search.except('links'), json_data_things.except('links'))
          assert(json_data_search != json_data_creative_works)
          assert_equal(json_data_search.except('links'), json_data_creative_works.except('links'))
        end

        test 'sorted article is also found in V1 and has the same values as V2' do
          get(api_v1_contents_search_path)
          assert_response(:success)
          assert_equal('application/json', response.content_type)
          json_data_search_old = JSON.parse(response.body)

          get(api_v2_contents_search_path)
          assert_response(:success)
          assert_equal('application/json', response.content_type)
          json_data_search = JSON.parse(response.body)
          data_hash = json_data_search['data'].first

          v1_hash = {
            '@context' => 'http://schema.org/thing',
            'contentType' => 'Artikel',
            '@id' => @content.id,
            'identifier' => "http://www.example.com/things/#{@content.id}",
            'url' => "http://www.example.com/things/#{@content.id}",
            'inLanguage' => 'de',
            'name' => 'TestArtikel'
          }
          v1_except = ['dateCreated', 'dateModified', 'classifications']

          v2_hash = {
            '@context' => data_hash['@context'] + '/thing',
            'contentType' => data_hash['contentType'],
            '@id' => data_hash['@id'].split('/').last,
            'identifier' => 'http://www.example.com/things/' + data_hash['identifier'],
            'url' => data_hash['url'],
            'inLanguage' => data_hash['inLanguage'],
            'name' => data_hash['headline']
          }

          v1_classifications = json_data_search_old['contents'].first.dig('classifications').map { |item| item.dig('name') }.sort
          v2_classifications = data_hash
            .select { |key, _value| ['classifications', 'releaseStatusId', 'dataPool'].include?(key) }
            .map { |_key, value| value.is_a?(::Array) ? value.map { |item| item.dig('name') } : value.dig('name') }
            .flatten
            .sort

          assert_equal(v1_hash, json_data_search_old['contents'].first.except(*v1_except))
          assert_equal(v1_hash, v2_hash)
          assert_equal(1, json_data_search_old['total'])
          assert_equal(json_data_search_old['total'], json_data_search.dig('meta', 'total'))
          assert_equal(v1_classifications, v2_classifications)
        end
      end
    end
  end
end