# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Xml
    module V1
      class WatchListsTest < DataCycleCore::TestCases::ActionDispatchIntegrationTest
        before(:all) do
          DataCycleCore::Thing.delete_all
          @content = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'TestArtikel' })
          @watch_list = DataCycleCore::TestPreparations.create_watch_list(name: 'TestWatchList')
        end

        setup do
          sign_in(User.find_by(email: 'tester@datacycle.at'))
        end

        test 'create Watchlist, add data and retrieve data as xml while doing so' do
          # create watchlist
          name = "test_watch_list_#{Time.now.getutc.to_i}"
          post(
            watch_lists_path, xhr: true, params: {
              watch_list: {
                full_path: name
              }
            }, headers: {
              referer: root_path
            }
          )

          assert_response(:success)
          assert_equal(DataCycleCore::WatchList.where(name: name).size, 1)

          # read watch_list as xml
          get(xml_v1_collections_path)
          assert_response(:success)
          assert_equal(response.content_type, 'application/xml; charset=utf-8')
          xml_data = Hash.from_xml(Nokogiri::XML(response.body).to_xml).dig('RDF', 'collections')
          assert_equal(1, xml_data.dig('collection').count { |w| w['name'] == name })

          # add data to watchlist
          get(add_item_watch_list_path(@watch_list), xhr: true, params: {
            hashable_id: @content.id,
            hashable_type: @content.class.name
          }, headers: {
            referer: root_path
          })
          assert_response(:success)

          # read wattch_list with one data entry
          get(xml_v1_collection_path(@watch_list))
          assert_response(:success)
          assert_equal(response.content_type, 'application/xml; charset=utf-8')
          xml_data = Hash.from_xml(Nokogiri::XML(response.body).to_xml).dig('RDF', 'collection')
          assert_equal(@content.name, xml_data.dig('things', 'thing', 'name'))
        end
      end
    end
  end
end
