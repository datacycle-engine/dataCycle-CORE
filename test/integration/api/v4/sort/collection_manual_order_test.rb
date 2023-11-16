# frozen_string_literal: true

require 'v4/base'

module DataCycleCore
  module Api
    module V4
      module Sort
        class CollectionManualOrderTest < DataCycleCore::V4::Base
          before(:all) do
            @collection = DataCycleCore::TestPreparations.create_watch_list(name: 'Inhaltssammlung 1')
            @collection.update_column(:manual_order, true)
            @content = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'Test Artikel 1 in Collection' }, prevent_history: true)
            @content2 = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'Test Artikel 2 in Collection' }, prevent_history: true)
            @content3 = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'Test Artikel 3 in Collection' }, prevent_history: true)
            @content4 = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'Test Artikel 4 in Collection' }, prevent_history: true)
            @content5 = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'Test Artikel 5 in Collection' }, prevent_history: true)

            @content.watch_lists << @collection
            @content2.watch_lists << @collection
            @content3.watch_lists << @collection
            @content4.watch_lists << @collection
            @content5.watch_lists << @collection
          end

          test 'api/v4/endpoints with default sorting without manual order' do
            @collection.update_column(:manual_order, false)
            params = {
              fields: '@id'
            }
            post api_v4_stored_filter_path(id: @collection.id, **params)
            json_data = response.parsed_body

            assert_equal([@content5.id, @content4.id, @content3.id, @content2.id, @content.id], json_data.dig('@graph').pluck('@id'))
          end

          test 'api/v4/endpoints with default sorting for manual order' do
            params = {
              fields: '@id'
            }
            post api_v4_stored_filter_path(id: @collection.id, **params)
            json_data = response.parsed_body

            assert_equal([@content.id, @content2.id, @content3.id, @content4.id, @content5.id], json_data.dig('@graph').pluck('@id'))
          end

          test 'api/v4/endpoints with default sorting for adjusted manual order' do
            @collection.update_order_by_array([@content3.id, @content5.id, @content.id, @content4.id, @content2.id])

            params = {
              fields: '@id'
            }
            post api_v4_stored_filter_path(id: @collection.id, **params)
            json_data = response.parsed_body

            assert_equal([@content3.id, @content5.id, @content.id, @content4.id, @content2.id], json_data.dig('@graph').pluck('@id'))
          end
        end
      end
    end
  end
end
