# frozen_string_literal: true

require 'v4/base'

module DataCycleCore
  module Api
    module V4
      module Content
        class ThingDataTest < DataCycleCore::V4::Base
          setup do
            @event = DataCycleCore::V4::DummyDataHelper.create_data('event')
          end

          # TODO: missing tests
          # - overlay
          # - linked_thing
          # - is_linked_to
          # - subject_of

          test 'api_v4_thing_path validate full event with default params' do
            assert_full_thing_datahash(@event)

            params = {
              id: @event.id
            }
            post api_v4_thing_path(params)
            json_data = JSON.parse response.body
            json_validate = json_data.dup

            # validate context
            json_context = json_validate.delete('@context')
            assert_equal(2, json_context.size)
            assert_equal('http://schema.org', json_context.first)
            validator = DataCycleCore::V4::Validation::Context.context
            assert_equal({}, validator.call(json_context.second).errors.to_h)

            # test full event data
            required_attributes = required_validation_attributes(@event)

            # test minimal
            assert_attributes(json_validate, required_attributes, ['id', 'name']) do
              {
                '@id' => @event.id,
                '@type' => 'Event',
                'name' => @event.name
              }
            end

            # plain attributes without transformation
            assert_attributes(json_validate, required_attributes, ['description', 'potential_action']) do
              {
                'description' => @event.description,
                'potentialAction' => @event.potential_action
              }
            end

            # plain external attributes without transformation
            assert_attributes(json_validate, required_attributes, ['url']) do
              {
                'sameAs' => @event.url
              }
            end

            # computed attributes
            assert_attributes(json_validate, required_attributes, ['start_date', 'end_date']) do
              {
                'startDate' => @event.start_date.as_json,
                'endDate' => @event.end_date.as_json
              }
            end

            # disabled attributes
            assert_attributes(json_validate, required_attributes, ['validity_period']) do
              {}
            end

            # cc_rel
            assert_attributes(json_validate, required_attributes, ['license', 'use_guidelines', 'attribution_url', 'attribution_name', 'more_permissions', 'license_classification']) do
              # license is overwritten by license_classification
              {
                'cc:license' => @event.license_classification.first.classification_aliases.first.uri,
                'cc:useGuidelines' => @event.use_guidelines,
                'cc:attributionUrl' => @event.attribution_url,
                'cc:attributionName' => @event.attribution_name,
                'cc:morePermissions' => @event.more_permissions
              }
            end

            # linked default: images, organizer, performer
            assert_attributes(json_validate, required_attributes, ['image', 'organizer', 'performer']) do
              {
                'image' => [
                  @event.image.first.to_api_default_values
                ],
                'organizer' => [
                  @event.organizer.first.to_api_default_values
                ],
                'performer' => [
                  @event.performer.first.to_api_default_values
                ]
              }
            end

            # embedded default: offers
            assert_attributes(json_validate, required_attributes, ['offers']) do
              {
                'offers' => [
                  @event.offers.first.to_api_default_values
                ]
              }
            end

            # same_as => potentialAction
            assert_attributes(json_validate, required_attributes, ['same_as']) do
              {
                'additionalProperty' => [
                  {
                    '@type' => 'PropertyValue',
                    'identifier' => 'link',
                    'value' => @event.same_as,
                    'name' => 'Link'
                  }
                ]
              }
            end

            # transformed classifications: event_status, event_attendance_mode
            assert_attributes(json_validate, required_attributes, ['event_status', 'event_attendance_mode']) do
              {
                'eventStatus' => @event.event_status.first.classification_aliases.first.uri,
                'eventAttendanceMode' => @event.event_attendance_mode.first.classification_aliases.first.uri
              }
            end

            # schedule: event_schedule
            assert_attributes(json_validate, required_attributes, ['event_schedule']) do
              {
                'eventSchedule' => [
                  @event.event_schedule.first.to_api_default_values
                ]
              }
            end

            # locations content_location, virtual_location
            assert_attributes(json_validate, required_attributes, ['content_location', 'virtual_location']) do
              {
                'location' => [
                  @event.content_location.first.to_api_default_values,
                  @event.virtual_location.first.to_api_default_values
                ]
              }
            end

            # locations content_location, virtual_location
            assert_attributes(json_validate, required_attributes, ['super_event']) do
              {
                'superEvent' => [
                  @event.super_event.first.to_api_default_values
                ]
              }
            end

            assert_classifications(json_validate, @event.classification_aliases.to_a.select { |c| c.visible?('api') }.map(&:to_api_default_values))

            assert_equal([], required_attributes)
            assert_equal({}, json_validate)
          end

          # in future test ignore linked data if a test already exists for the template
          # full test only must validate embedded and schedules
          test 'api_v4_thing_path validate full event with all linked/embedded/scheduled data' do
            assert_full_thing_datahash(@event)
            params = {
              id: @event.id,
              include: 'offers,offers.priceSpecification,offers.itemOffered,eventSchedule,location'
            }
            post api_v4_thing_path(params)
            json_data = JSON.parse response.body
            json_validate = json_data.dup

            # validate context
            json_context = json_validate.delete('@context')
            assert_equal(2, json_context.size)
            assert_equal('http://schema.org', json_context.first)
            validator = DataCycleCore::V4::Validation::Context.context
            assert_equal({}, validator.call(json_context.second).errors.to_h)

            # test full event data
            required_attributes = required_validation_attributes(@event)

            # test minimal
            assert_attributes(json_validate, required_attributes, ['id', 'name']) do
              {
                '@id' => @event.id,
                '@type' => 'Event',
                'name' => @event.name
              }
            end

            # plain attributes without transformation
            assert_attributes(json_validate, required_attributes, ['description', 'potential_action']) do
              {
                'description' => @event.description,
                'potentialAction' => @event.potential_action
              }
            end

            # plain external attributes without transformation
            assert_attributes(json_validate, required_attributes, ['url']) do
              {
                'sameAs' => @event.url
              }
            end

            # computed attributes
            assert_attributes(json_validate, required_attributes, ['start_date', 'end_date']) do
              {
                'startDate' => @event.start_date.as_json,
                'endDate' => @event.end_date.as_json
              }
            end

            # disabled attributes
            assert_attributes(json_validate, required_attributes, ['validity_period']) do
              {}
            end

            # cc_rel
            assert_attributes(json_validate, required_attributes, ['license', 'use_guidelines', 'attribution_url', 'attribution_name', 'more_permissions', 'license_classification']) do
              # license is overwritten by license_classification
              {
                'cc:license' => @event.license_classification.first.classification_aliases.first.uri,
                'cc:useGuidelines' => @event.use_guidelines,
                'cc:attributionUrl' => @event.attribution_url,
                'cc:attributionName' => @event.attribution_name,
                'cc:morePermissions' => @event.more_permissions
              }
            end

            assert_attributes(json_validate, required_attributes, ['image', 'organizer', 'performer']) do
              {
                'image' => [
                  @event.image.first.to_api_default_values
                ],
                'organizer' => [
                  @event.organizer.first.to_api_default_values
                ],
                'performer' => [
                  @event.performer.first.to_api_default_values
                ]
              }
            end

            # embedded full: offers
            # offers inside service (itemOffered) entity must be testet in a seperate service test
            # classifications must not be validated
            json_validate['offers'].first.delete('dc:classification')
            offer_object = @event.offers.first
            json_validate['offers'].first['priceSpecification'].first.delete('dc:classification')
            json_validate['offers'].first['itemOffered'].first.delete('dc:classification')
            price_specification_object = offer_object.price_specification.first
            item_offered_object = offer_object.item_offered.first

            price_specification_api_values = {
              '@id' => price_specification_object.id,
              '@type' => 'UnitPriceSpecification',
              'name' => price_specification_object.template_name,
              'price' => price_specification_object.price,
              'minPrice' => price_specification_object.min_price,
              'maxPrice' => price_specification_object.max_price,
              'unitText' => price_specification_object.unit_text,
              'validFrom' => price_specification_object.validity_period.valid_from.as_json,
              'validThrough' => price_specification_object.validity_period.valid_through.as_json
            }

            item_offered_api_values = {
              '@id' => item_offered_object.id,
              '@type' => 'Intangible',
              'name' => item_offered_object.name,
              'description' => item_offered_object.description,
              'sameAs' => item_offered_object.url,
              'hoursAvailable' => [
                item_offered_object.hours_available.first.to_api_default_values
              ],
              'additionalProperty' => [
                {
                  '@type' => 'PropertyValue',
                  'identifier' => 'text',
                  'name' => 'Beschreibung (lang)',
                  'value' => item_offered_object.text
                },
                {
                  '@type' => 'PropertyValue',
                  'identifier' => 'meetingPoint',
                  'name' => 'Treffpunkt',
                  'value' => item_offered_object.meeting_point
                },
                {
                  '@type' => 'PropertyValue',
                  'identifier' => 'equipment',
                  'name' => 'Ausrüstung',
                  'value' => item_offered_object.equipment
                },
                {
                  '@type' => 'PropertyValue',
                  'identifier' => 'requirements',
                  'name' => 'Voraussetzungen',
                  'value' => item_offered_object.requirements
                },
                {
                  '@type' => 'PropertyValue',
                  'identifier' => 'includedServices',
                  'name' => 'Services inkludiert',
                  'value' => item_offered_object.included_services
                },
                {
                  '@type' => 'PropertyValue',
                  'identifier' => 'difficulty',
                  'name' => 'Schwierigkeitsgrad',
                  'value' => item_offered_object.difficulty
                }
              ]
            }

            offer_api_values = {
              '@id' => offer_object.id,
              '@type' => 'Offer',
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
                '@type' => 'Action',
                'name' => offer_object.potentialAction.name,
                'url' => offer_object.potentialAction.url
              },
              'additionalProperty' => [
                {
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
            assert_attributes(json_validate, required_attributes, ['same_as']) do
              {
                'additionalProperty' => [
                  {
                    '@type' => 'PropertyValue',
                    'identifier' => 'link',
                    'value' => @event.same_as,
                    'name' => 'Link'
                  }
                ]
              }
            end

            # transformed classifications: event_status, event_attendance_mode
            assert_attributes(json_validate, required_attributes, ['event_status', 'event_attendance_mode']) do
              {
                'eventStatus' => @event.event_status.first.classification_aliases.first.uri,
                'eventAttendanceMode' => @event.event_attendance_mode.first.classification_aliases.first.uri
              }
            end

            # schedule: event_schedule
            event_schedule_object = @event.event_schedule.first.to_h
            event_schedule_api_values = {
              '@id' => event_schedule_object.dig(:id),
              '@type' => 'Schedule',
              '@context' => 'http://schema.org',
              'inLanguage' => 'de',
              'startDate' => event_schedule_object.dig(:dtstart).to_s(:only_date),
              'endDate' => event_schedule_object.dig(:dtend).to_s(:only_date),
              'startTime' => event_schedule_object.dig(:dtstart).to_s(:only_time),
              'endTime' => event_schedule_object.dig(:dtend).to_s(:only_time),
              'duration' => event_schedule_object.dig(:duration).iso8601
            }
            assert_attributes(json_validate, required_attributes, ['event_schedule']) do
              {
                'eventSchedule' => [
                  event_schedule_api_values
                ]
              }
            end

            # locations content_location, virtual_location

            json_validate['location'].each { |location| location.delete('dc:classification') }
            content_location_object = @event.content_location.first
            virtual_location_object = @event.virtual_location.first
            content_location_api_values = {
              '@id' => content_location_object.id,
              '@type' => 'TouristAttraction',
              'name' => content_location_object.title,
              'geo' => {
                'longitude' => content_location_object.longitude,
                '@type' => 'GeoCoordinates',
                'latitude' => content_location_object.latitude,
                'elevation' => content_location_object.elevation
              },
              'address' => {
                # "@type" => "PostalAddress",
                # "streetAddress" => content_location_object.address.street_address,
                # "postalCode" => content_location_object.address.postal_code,
                # "addressLocality" => content_location_object.address.address_locality,
                # "addressCountry" => content_location_object.address.address_country,
                'name' => content_location_object.contact_info.name,
                'telephone' => content_location_object.contact_info.telephone,
                'faxNumber' => content_location_object.contact_info.fax_number,
                'email' => content_location_object.contact_info.email,
                'url' => content_location_object.contact_info.url
              },
              'description' => content_location_object.description,
              'image' => [
                content_location_object.image.first.to_api_default_values
              ],
              'additionalProperty' => [
                {
                  '@type' => 'PropertyValue',
                  'identifier' => 'text',
                  'name' => 'Beschreibung',
                  'value' => content_location_object.text
                },
                {
                  '@type' => 'PropertyValue',
                  'identifier' => 'priceRange',
                  'name' => 'Preis-Info',
                  'value' => content_location_object.price_range
                }
              ]
            }

            virtual_location_api_values = {
              '@id' => virtual_location_object.id,
              '@type' => 'VirtualLocation',
              'name' => virtual_location_object.name,
              'url' => virtual_location_object.url
            }

            assert_attributes(json_validate, required_attributes, ['content_location', 'virtual_location']) do
              {
                'location' => [
                  content_location_api_values,
                  virtual_location_api_values
                ]
              }
            end

            # testing super_events
            assert_attributes(json_validate, required_attributes, ['super_event']) do
              {
                'superEvent' => [
                @event.super_event.first.to_api_default_values
                ]
              }
            end

            assert_classifications(json_validate, @event.classification_aliases.to_a.select { |c| c.visible?('api') }.map(&:to_api_default_values))

            assert_equal([], required_attributes)
            assert_equal({}, json_validate)
          end
        end
      end
    end
  end
end
