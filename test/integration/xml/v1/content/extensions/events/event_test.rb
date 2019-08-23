# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Xml
    module V1
      module Content
        module Extensions
          module Events
            class Event < ActionDispatch::IntegrationTest
              include Devise::Test::IntegrationHelpers
              include Engine.routes.url_helpers

              setup do
                @routes = Engine.routes
                @content = DataCycleCore::DummyDataHelper.create_data('event')
                sign_in(User.find_by(email: 'tester@datacycle.at'))
              end

              test 'xml of stored content exists and is correct' do
                get xml_v1_thing_path(id: @content)

                assert_response(:success)
                assert_equal('application/xml', response.content_type)
                xml_data = Hash.from_xml(Nokogiri::XML(response.body).to_xml).dig('RDF', 'thing')

                # validate header
                assert_equal('http://schema.org', xml_data.dig('context'))
                assert_equal('Event', xml_data.dig('type'))
                assert_equal('Event', xml_data.dig('contentType'))
                assert_equal(root_url[0...-1] + xml_v1_thing_path(id: @content), xml_data.dig('id'))
                assert_equal(@content.id, xml_data.dig('identifier'))
                assert_equal(root_url[0...-1] + thing_path(@content), xml_data.dig('url'))
                assert_equal('de', xml_data.dig('inLanguage'))

                # startDate / endDate
                assert_equal(@content.event_period.start_date, xml_data.dig('eventPeriod', 'startDate'))
                assert_equal(@content.event_period.end_date, xml_data.dig('eventPeriod', 'endDate'))

                # content data
                assert_equal(@content.name, xml_data.dig('name'))
                assert_equal(@content.description, xml_data.dig('description'))
                assert_equal(@content.url, xml_data.dig('sameAs'))
                assert_equal(@content.same_as, xml_data.dig('link'))

                # TODO: check image rendering via minimal or linked
                assert_equal(@content.image.first.id, xml_data.dig('image', 'thing', 'identifier'))
                assert_equal(@content.content_location.first.id, xml_data.dig('contentLocation', 'thing', 'identifier'))

                # sub_events
                sub_events = @content.sub_event.map do |sub_event|
                  {
                    'context' => 'http://schema.org',
                    'type' => 'Event',
                    'contentType' => 'SubEvent',
                    'name' => sub_event.name,
                    'description' => sub_event.description,
                    'sameAs' => sub_event.url,
                    'eventPeriod' => {
                      'startDate' => sub_event.event_period.start_date,
                      'endDate' => sub_event.event_period.end_date
                    }
                  }
                end
                assert_equal(sub_events, xml_data.dig('subEvent', 'subEvent'))
              end

              test 'testing EventOverlay' do
                image_data_hash = DataCycleCore::TestPreparations.load_dummy_data_hash('creative_works', 'api_image')
                image_data_hash['name'] = 'Another Image'
                overlay_image = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: image_data_hash)

                place_data_hash = DataCycleCore::TestPreparations.load_dummy_data_hash('places', 'api_poi')
                place_data_hash['name'] = 'Another Place'
                overlay_place = DataCycleCore::TestPreparations.create_content(template_name: 'POI', data_hash: place_data_hash)

                data_hash = {
                  'overlay' => [
                    {
                      'name' => 'overlay_name',
                      'description' => 'overlay_description',
                      'image' => [overlay_image.id],
                      'content_location' => [overlay_place.id],
                      'url' => 'https://overlay.url.com',
                      'event_period' => {
                        'start_date' => '2019-11-10T00:00:00.000+01:00',
                        'end_date' => '2019-11-20T00:00:00.000+01:00'
                      }
                    }
                  ]
                }
                I18n.with_locale(:de) do
                  @content.set_data_hash(data_hash: data_hash, partial_update: true, current_user: User.find_by(email: 'tester@datacycle.at'))
                end
                @content.reload

                get xml_v1_thing_path(id: @content)

                assert_response(:success)
                assert_equal('application/xml', response.content_type)

                xml_data = Hash.from_xml(Nokogiri::XML(response.body).to_xml).dig('RDF', 'thing')

                # content data
                assert_equal(data_hash.dig('overlay').first.dig('event_period', 'start_date').to_datetime, xml_data.dig('eventPeriod', 'startDate'))
                assert_equal(data_hash.dig('overlay').first.dig('event_period', 'end_date').to_datetime, xml_data.dig('eventPeriod', 'endDate'))
                assert_equal(data_hash.dig('overlay').first.dig('name'), xml_data.dig('name'))
                assert_equal(data_hash.dig('overlay').first.dig('description'), xml_data.dig('description'))
                assert_equal(data_hash.dig('overlay').first.dig('url'), xml_data.dig('sameAs'))
                assert_equal(overlay_image.id, xml_data.dig('image', 'thing', 'identifier'))
                assert_equal(overlay_place.id, xml_data.dig('contentLocation', 'thing', 'identifier'))
              end

              test 'testing partial EventOverlay, empty Overlay fields do not overwrite Event' do
                data_hash = {
                  'overlay' => [
                    {
                      'name' => 'overlay_name',
                      'description' => 'overlay_description'
                    }
                  ]
                }
                I18n.with_locale(:de) do
                  @content.set_data_hash(data_hash: data_hash, partial_update: true, current_user: User.find_by(email: 'tester@datacycle.at'))
                end
                @content.reload

                get xml_v1_thing_path(id: @content)

                assert_response(:success)
                assert_equal('application/xml', response.content_type)

                xml_data = Hash.from_xml(Nokogiri::XML(response.body).to_xml).dig('RDF', 'thing')

                # overwritten data
                assert_equal(data_hash.dig('overlay').first.dig('name'), xml_data.dig('name'))
                assert_equal(data_hash.dig('overlay').first.dig('description'), xml_data.dig('description'))
                # not overwritten data
                assert_equal(@content.event_period.start_date.to_s, xml_data.dig('eventPeriod', 'startDate'))
                assert_equal(@content.event_period.end_date.to_s, xml_data.dig('eventPeriod', 'endDate'))
                assert_equal(@content.url, xml_data.dig('sameAs'))
                assert_equal(@content.image.first.id, xml_data.dig('image', 'thing', 'identifier'))
                assert_equal(@content.content_location.first.id, xml_data.dig('contentLocation', 'thing', 'identifier'))
              end

              test 'stored item can be found via different endpoints' do
                get(xml_v1_things_path)
                assert_response(:success)
                assert_equal('application/xml', response.content_type)
                xml_data = [Hash.from_xml(Nokogiri::XML(response.body).to_xml).dig('RDF', 'thing')].flatten.detect { |item| item&.dig('contentType') == 'Event' }
                assert_equal(@content.id, xml_data.dig('identifier'))

                get(xml_v1_contents_search_path)
                assert_response(:success)
                assert_equal('application/xml', response.content_type)
                xml_data = [Hash.from_xml(Nokogiri::XML(response.body).to_xml).dig('RDF', 'thing')].flatten.detect { |item| item&.dig('contentType') == 'Event' }
                assert_equal(@content.id, xml_data.dig('identifier'))

                get(xml_v1_events_path)
                assert_response(:success)
                assert_equal('application/xml', response.content_type)
                xml_data = [Hash.from_xml(Nokogiri::XML(response.body).to_xml).dig('RDF', 'thing')].flatten.detect { |item| item&.dig('contentType') == 'Event' }
                assert_equal(@content.id, xml_data.dig('identifier'))
              end
            end
          end
        end
      end
    end
  end
end
