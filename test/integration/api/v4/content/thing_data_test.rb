# frozen_string_literal: true

require 'v4/base'

module DataCycleCore
  module Api
    module V4
      module Content
        class ThingDataTest < DataCycleCore::V4::Base
          include DataCycleCore::ApiHelper

          before(:all) do
            @content = DataCycleCore::V4::DummyDataHelper.create_data('event')
          end

          # TODO: missing tests
          # - overlay
          # - linked_thing
          # - is_linked_to
          # - subject_of

          test 'api_v4_thing_path validate full event with default params' do
            assert_full_thing_datahash(@content)
            params = {
              id: @content.id
            }
            post api_v4_thing_path(params)
            json_data = response.parsed_body
            json_validate = json_data.dup.dig('@graph').first

            assert_context(json_data.dig('@context'), 'de')

            # test full event data
            required_attributes = required_validation_attributes(@content)

            # test minimal
            assert_attributes(json_validate, required_attributes, ['id', 'name']) do
              {
                '@id' => @content.id,
                '@type' => @content.api_type,
                'name' => @content.name
              }
            end

            # validate language
            assert_attributes(json_validate, required_attributes, []) do
              {
                'dc:multilingual' => true,
                'dc:translation' => [
                  'de'
                ]
              }
            end

            # plain attributes without transformation
            assert_attributes(json_validate, required_attributes, ['description']) do
              {
                'description' => @content.description
              }
            end

            # potential_action
            assert_attributes(json_validate, required_attributes, ['potential_action']) do
              {
                'potentialAction' => [
                  @content.potential_action.first.to_api_default_values
                ]
              }
            end

            # plain external attributes without transformation
            assert_attributes(json_validate, required_attributes, ['url', 'dc:slug']) do
              {
                'sameAs' => @content.url,
                'dc:slug' => @content.slug
              }
            end

            # computed attributes
            assert_attributes(json_validate, required_attributes, ['start_date', 'end_date']) do
              {
                'startDate' => @content.start_date.as_json,
                'endDate' => @content.end_date.as_json
              }
            end

            # disabled attributes
            assert_attributes(json_validate, required_attributes, ['validity_period']) do
              {}
            end

            # cc_rel
            assert_attributes(json_validate, required_attributes, ['url', 'license', 'use_guidelines', 'attribution_url', 'attribution_name', 'license_classification']) do
              # license is overwritten by license_classification
              {
                'cc:license' => @content.license_classification.first.classification_aliases.first.uri,
                'cc:useGuidelines' => @content.use_guidelines,
                'url' => @content.attribution_url,
                'copyrightNotice' => @content.copyright_notice_computed
              }
            end

            # linked default: images, organizer, performer
            assert_attributes(json_validate, required_attributes, ['image', 'organizer', 'performer']) do
              {
                'image' => [
                  @content.image.first.to_api_default_values
                ],
                'organizer' => [
                  @content.organizer.first.to_api_default_values
                ],
                'performer' => [
                  @content.performer.first.to_api_default_values
                ]
              }
            end

            # embedded default: offers
            assert_attributes(json_validate, required_attributes, ['offers']) do
              {
                'offers' => [
                  @content.offers.first.to_api_default_values
                ]
              }
            end

            # same_as => additionalProperty
            assert_attributes(json_validate, required_attributes, ['same_as', 'feratel_content_score', 'content_score']) do
              {
                'additionalProperty' => [
                  {
                    '@id' => generate_uuid(@content.id, 'same_as'),
                    '@type' => 'PropertyValue',
                    'identifier' => 'link',
                    'value' => @content.same_as,
                    'name' => 'Link'
                  },
                  {
                    '@id' => generate_uuid(@content.id, 'feratel_content_score'),
                    '@type' => 'PropertyValue',
                    'identifier' => 'feratelContentScore',
                    'name' => 'ContentScore (Feratel)',
                    'value' => @content.feratel_content_score
                  },
                  {
                    '@id' => generate_uuid(@content.id, 'content_score'),
                    '@type' => 'PropertyValue',
                    'identifier' => 'contentScore',
                    'name' => 'ContentScore',
                    'value' => @content.content_score
                  }
                ]
              }
            end

            # transformed classifications: event_status, event_attendance_mode
            assert_attributes(json_validate, required_attributes, ['event_status', 'event_attendance_mode']) do
              {
                'eventStatus' => @content.event_status.first.classification_aliases.first.uri,
                'eventAttendanceMode' => @content.event_attendance_mode.first.classification_aliases.first.uri
              }
            end

            # schedule: event_schedule
            assert_attributes(json_validate, required_attributes, ['event_schedule']) do
              {
                'eventSchedule' => [
                  @content.event_schedule.first.to_api_default_values
                ]
              }
            end

            # locations content_location, virtual_location
            assert_attributes(json_validate, required_attributes, ['content_location', 'virtual_location']) do
              {
                'location' => [
                  @content.content_location.first.to_api_default_values,
                  @content.virtual_location.first.to_api_default_values
                ]
              }
            end

            # locations super_event
            assert_attributes(json_validate, required_attributes, ['super_event']) do
              {
                'superEvent' => [
                  @content.super_event.first.to_api_default_values
                ]
              }
            end

            assert_classifications(json_validate, @content.classification_aliases.to_a.select { |c| c.visible?('api') }.map(&:to_api_default_values))

            assert_equal([], required_attributes)
            assert_equal({}, json_validate)
          end

          # in future test ignore linked data if a test already exists for the template
          # full test only must validate embedded and schedules
          test 'api_v4_thing_path validate full event with all linked/embedded/scheduled data' do
            assert_full_thing_datahash(@content)
            params = {
              id: @content.id,
              include: 'offers,offers.priceSpecification,offers.itemOffered,eventSchedule,location'
            }
            post api_v4_thing_path(params)
            json_data = response.parsed_body
            json_validate = json_data.dup.dig('@graph').first

            assert_context(json_data.dig('@context'), 'de')

            # test full event data
            required_attributes = required_validation_attributes(@content)

            # test minimal
            assert_attributes(json_validate, required_attributes, ['id', 'name']) do
              {
                '@id' => @content.id,
                '@type' => @content.api_type,
                'name' => @content.name
              }
            end

            # validate language
            assert_attributes(json_validate, required_attributes, []) do
              {
                'dc:multilingual' => true,
                'dc:translation' => [
                  'de'
                ]
              }
            end

            # plain attributes without transformation
            assert_attributes(json_validate, required_attributes, ['description']) do
              {
                'description' => @content.description
              }
            end

            # potential_action
            assert_attributes(json_validate, required_attributes, ['potential_action']) do
              {
                'potentialAction' => [
                  @content.potential_action.first.to_api_default_values
                ]
              }
            end

            # plain external attributes without transformation
            assert_attributes(json_validate, required_attributes, ['url', 'dc:slug']) do
              {
                'sameAs' => @content.url,
                'dc:slug' => @content.slug
              }
            end

            # computed attributes
            assert_attributes(json_validate, required_attributes, ['start_date', 'end_date']) do
              {
                'startDate' => @content.start_date.as_json,
                'endDate' => @content.end_date.as_json
              }
            end

            # disabled attributes
            assert_attributes(json_validate, required_attributes, ['validity_period']) do
              {}
            end

            # cc_rel
            assert_attributes(json_validate, required_attributes, ['url', 'license', 'use_guidelines', 'attribution_url', 'attribution_name', 'license_classification']) do
              # license is overwritten by license_classification
              {
                'cc:license' => @content.license_classification.first.classification_aliases.first.uri,
                'cc:useGuidelines' => @content.use_guidelines,
                'url' => @content.attribution_url,
                'copyrightNotice' => @content.copyright_notice_computed
              }
            end

            assert_attributes(json_validate, required_attributes, ['image', 'organizer', 'performer']) do
              {
                'image' => [
                  @content.image.first.to_api_default_values
                ],
                'organizer' => [
                  @content.organizer.first.to_api_default_values
                ],
                'performer' => [
                  @content.performer.first.to_api_default_values
                ]
              }
            end

            # embedded full: offers
            # offers inside service (itemOffered) entity must be testet in a seperate service test
            # classifications must not be validated
            json_validate['offers'].first.delete('dc:classification')
            offer_object = @content.offers.first
            json_validate['offers'].first['priceSpecification'].first.delete('dc:classification')
            json_validate['offers'].first['itemOffered'].first.delete('dc:classification')
            price_specification_object = offer_object.price_specification.first
            item_offered_object = offer_object.item_offered.first

            price_specification_api_values = {
              '@id' => price_specification_object.id,
              '@type' => price_specification_object.api_type,
              'dc:multilingual' => true,
              'dc:translation' => [
                'de'
              ],
              'price' => price_specification_object.price,
              'minPrice' => price_specification_object.min_price,
              'maxPrice' => price_specification_object.max_price,
              'unitText' => price_specification_object.unit_text,
              'validFrom' => price_specification_object.validity_period.valid_from.as_json,
              'validThrough' => price_specification_object.validity_period.valid_through.as_json
            }

            item_offered_api_values = {
              '@id' => item_offered_object.id,
              '@type' => item_offered_object.api_type,
              'dc:multilingual' => true,
              'dc:translation' => [
                'de'
              ],
              'name' => item_offered_object.name,
              'description' => item_offered_object.description,
              'dc:additionalInformation' => [{
                '@id' => item_offered_object.additional_information.first.id,
                '@type' => item_offered_object.additional_information.first.api_type
              }],
              'sameAs' => item_offered_object.url,
              'hoursAvailable' => [
                item_offered_object.hours_available.first.to_api_default_values
              ],
              'dc:slug' => item_offered_object.slug,
              'additionalProperty' => [
                {
                  '@id' => generate_uuid(item_offered_object.id, 'text'),
                  '@type' => 'PropertyValue',
                  'identifier' => 'text',
                  'name' => 'Beschreibung (lang)',
                  'value' => item_offered_object.text
                }
              ]
            }

            offer_api_values = {
              '@id' => offer_object.id,
              '@type' => offer_object.api_type,
              'dc:multilingual' => true,
              'dc:translation' => [
                'de'
              ],
              'name' => offer_object.name,
              'description' => offer_object.description,
              'price' => offer_object.price,
              'priceSpecification' => [
                price_specification_api_values
              ],
              'sameAs' => offer_object.url,
              'offeredBy' => [
                offer_object.offered_by.first.to_api_default_values
              ],
              'itemOffered' => [
                item_offered_api_values
              ],
              'validFrom' => offer_object.offer_period.valid_from.as_json,
              'validThrough' => offer_object.offer_period.valid_through.as_json,
              'potentialAction' => {
                '@id' => generate_uuid(offer_object.id, 'potential_action'),
                '@type' => 'Action',
                'name' => offer_object.potential_action.action_name,
                'url' => offer_object.potential_action.action_url
              },
              'additionalProperty' => [
                {
                  '@id' => generate_uuid(offer_object.id, 'text'),
                  '@type' => 'PropertyValue',
                  'identifier' => 'text',
                  'name' => 'Beschreibung (lang)',
                  'value' => offer_object.text
                }
              ]
            }

            assert_attributes(json_validate, required_attributes, ['offers']) do
              {
                'offers' => [
                  offer_api_values
                ]
              }
            end

            # same_as => potentialAction
            assert_attributes(json_validate, required_attributes, ['same_as', 'feratel_content_score', 'content_score']) do
              {
                'additionalProperty' => [
                  {
                    '@id' => generate_uuid(@content.id, 'same_as'),
                    '@type' => 'PropertyValue',
                    'identifier' => 'link',
                    'value' => @content.same_as,
                    'name' => 'Link'
                  },
                  {
                    '@id' => generate_uuid(@content.id, 'feratel_content_score'),
                    '@type' => 'PropertyValue',
                    'identifier' => 'feratelContentScore',
                    'name' => 'ContentScore (Feratel)',
                    'value' => @content.feratel_content_score
                  },
                  {
                    '@id' => generate_uuid(@content.id, 'content_score'),
                    '@type' => 'PropertyValue',
                    'identifier' => 'contentScore',
                    'name' => 'ContentScore',
                    'value' => @content.content_score
                  }
                ]
              }
            end

            # transformed classifications: event_status, event_attendance_mode
            assert_attributes(json_validate, required_attributes, ['event_status', 'event_attendance_mode']) do
              {
                'eventStatus' => @content.event_status.first.classification_aliases.first.uri,
                'eventAttendanceMode' => @content.event_attendance_mode.first.classification_aliases.first.uri
              }
            end

            # schedule: event_schedule
            event_schedule_object = @content.event_schedule.first
            event_schedule_object_hash = event_schedule_object.to_h
            event_schedule_api_values = {
              '@id' => event_schedule_object_hash.dig(:id),
              '@type' => 'Schedule',
              '@context' => 'https://schema.org/',
              'inLanguage' => 'de',
              'startDate' => event_schedule_object_hash.dig(:dtstart).to_s(:only_date),
              'startTime' => event_schedule_object_hash.dig(:dtstart).to_s(:only_time),
              'endDate' => (event_schedule_object_hash.dig(:dtstart) + event_schedule_object.duration).to_s(:only_date),
              'endTime' => (event_schedule_object_hash.dig(:dtstart) + event_schedule_object.duration).to_s(:only_time),
              'duration' => event_schedule_object.iso8601_duration(event_schedule_object_hash.dig(:dtstart), event_schedule_object_hash.dig(:dtend)).iso8601,
              'scheduleTimezone' => 'Europe/Vienna'
            }
            assert_attributes(json_validate, required_attributes, ['event_schedule']) do
              {
                'eventSchedule' => [
                  event_schedule_api_values
                ]
              }
            end

            # locations content_location, virtual_location
            # only test virtual location, full content_location has been moved to poi_test
            json_validate['location'].each { |location| location.delete('dc:classification') }
            json_validate['location'] = [json_validate['location'].second]
            virtual_location_object = @content.virtual_location.first
            virtual_location_api_values = {
              '@id' => virtual_location_object.id,
              '@type' => virtual_location_object.api_type,
              'dc:multilingual' => false,
              'dc:translation' => [
                'de'
              ],
              'name' => virtual_location_object.name,
              'url' => virtual_location_object.url
            }

            assert_attributes(json_validate, required_attributes, ['content_location', 'virtual_location']) do
              {
                'location' => [
                  virtual_location_api_values
                ]
              }
            end

            # testing super_events
            assert_attributes(json_validate, required_attributes, ['super_event']) do
              {
                'superEvent' => [
                  @content.super_event.first.to_api_default_values
                ]
              }
            end

            assert_classifications(json_validate, @content.classification_aliases.to_a.select { |c| c.visible?('api') }.map(&:to_api_default_values))

            assert_equal([], required_attributes)
            assert_equal({}, json_validate)
          end
        end
      end
    end
  end
end
