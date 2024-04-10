# frozen_string_literal: true

require 'v4/base'

module DataCycleCore
  module Api
    module V4
      module Attributes
        class CollectionLinkTest < DataCycleCore::V4::Base
          before(:all) do
            @user = DataCycleCore::User.first
            @stored_filter = DataCycleCore::StoredFilter.create(name: 'test suche 1', user: @user, language: ['de'])
            @watch_list = DataCycleCore::WatchList.create(full_path: 'test Inhaltssammlung 1', user: @user)
            @content = DataCycleCore::TestPreparations.create_content(
              template_name: 'Entity-With-Collection-Link',
              data_hash: { name: 'Test Organization 1', collections: [@stored_filter.id, @watch_list.id] }
            )
          end

          test 'api/v4/things collection attribute order' do # rubocop:disable Minitest/MultipleAssertions
            post api_v4_thing_path(id: @content.id)
            json_data = response.parsed_body
            collections = json_data.dig('@graph', 0, 'collections')

            assert_equal @stored_filter.id, collections.first['@id']
            assert_equal @watch_list.id, collections.last['@id']
            assert_equal 'dcls:StoredFilter', collections.first['@type'].last
            assert_equal 'dcls:WatchList', collections.last['@type'].last
          end

          test 'api/v4/things collection attribute' do # rubocop:disable Minitest/MultipleAssertions
            post api_v4_thing_path(id: @content.id)
            json_data = response.parsed_body
            collections = json_data.dig('@graph', 0, 'collections')

            collections.each do |collection|
              assert collection.key?('@id')
              assert collection.key?('@type')
              assert collection.key?('name')
              assert collection.key?('url')
              assert collection.key?('dc:slug')
            end
          end

          test 'api/v4/things collection attribute with fields @id' do # rubocop:disable Minitest/MultipleAssertions
            post api_v4_thing_path(id: @content.id), params: { fields: 'collections.@id' }
            json_data = response.parsed_body
            collections = json_data.dig('@graph', 0, 'collections')

            collections.each do |collection|
              assert collection.key?('@id')
              assert collection.key?('@type')
              assert_not collection.key?('name')
              assert_not collection.key?('url')
              assert_not collection.key?('dc:slug')
            end
          end

          test 'api/v4/things collection attribute with fields name' do # rubocop:disable Minitest/MultipleAssertions
            post api_v4_thing_path(id: @content.id), params: { fields: 'collections.name' }
            json_data = response.parsed_body
            collections = json_data.dig('@graph', 0, 'collections')

            collections.each do |collection|
              assert collection.key?('@id')
              assert collection.key?('@type')
              assert collection.key?('name')
              assert_not collection.key?('url')
              assert_not collection.key?('dc:slug')
            end
          end

          test 'api/v4/things collection attribute with fields url' do # rubocop:disable Minitest/MultipleAssertions
            post api_v4_thing_path(id: @content.id), params: { fields: 'collections.url' }
            json_data = response.parsed_body
            collections = json_data.dig('@graph', 0, 'collections')

            collections.each do |collection|
              assert collection.key?('@id')
              assert collection.key?('@type')
              assert_not collection.key?('name')
              assert collection.key?('url')
              assert_not collection.key?('dc:slug')
            end
          end

          test 'api/v4/things collection attribute with fields dc:slug' do # rubocop:disable Minitest/MultipleAssertions
            post api_v4_thing_path(id: @content.id), params: { fields: 'collections.dc:slug' }
            json_data = response.parsed_body
            collections = json_data.dig('@graph', 0, 'collections')

            collections.each do |collection|
              assert collection.key?('@id')
              assert collection.key?('@type')
              assert_not collection.key?('name')
              assert_not collection.key?('url')
              assert collection.key?('dc:slug')
            end
          end
        end
      end
    end
  end
end
