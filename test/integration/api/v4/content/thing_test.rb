# frozen_string_literal: true

require 'test_helper'
require 'json'
require 'v4/helpers/dummy_data_helper'
require 'v4/helpers/api_helper'
require 'v4/validation/context'

module DataCycleCore
  module Api
    module V4
      class Thing < ActionDispatch::IntegrationTest
        include Devise::Test::IntegrationHelpers
        include Engine.routes.url_helpers
        include DataCycleCore::V4::ApiHelper
        include DataCycleCore::V4::DummyDataHelper

        setup do
          @routes = Engine.routes
          @event = DataCycleCore::V4::DummyDataHelper.create_data('event')
          sign_in(User.find_by(email: 'tester@datacycle.at'))
        end

        # test default event
        test 'api_v4_thing_path validate full event' do
          assert_full_thing_datahash(@event)
          params = {
            id: @event.id
          }
          post api_v4_thing_path(params)
          json_data = JSON.parse response.body

          # validate context
          json_context = json_data.delete('@context')
          assert_equal(2, json_context.size)
          assert_equal('http://schema.org', json_context.first)
          validator = DataCycleCore::V4::Validation::Context.context
          assert_equal({}, validator.call(json_context.second).errors.to_h)

          # test full event data
          required_attributes = required_validation_attributes(@event)

          # test minimal
          assert_attributes(required_attributes, ['id', 'name']) do
            assert_equal(@event.id, json_data.delete('@id'))
            assert_equal('Event', json_data.delete('@type'))
            assert_equal(@event.name, json_data.delete('name'))
          end

          # plain attributes without transformation
          assert_attributes(required_attributes, ['description', 'potential_action']) do
            assert_equal(@event.description, json_data.delete('description'))
            assert_equal(@event.potential_action, json_data.delete('potentialAction'))
          end

          # plain external attributes without transformation
          assert_attributes(required_attributes, ['url']) do
            assert_equal(@event.url, json_data.delete('sameAs'))
          end

          # computed attributes
          assert_attributes(required_attributes, ['start_date', 'end_date']) do
            assert_equal(@event.start_date.as_json, json_data.delete('startDate'))
            assert_equal(@event.end_date.as_json, json_data.delete('endDate'))
          end

          # disabled attributes
          assert_attributes(required_attributes, ['validity_period']) do
            assert_nil(json_data.dig('validity_period'))
          end

          # cc_rel
          assert_attributes(required_attributes, ['license', 'use_guidelines', 'attribution_url', 'attribution_name', 'more_permissions', 'license_classification']) do
            # license is overwritten by license_classification
            assert_not_equal(@event.license, json_data.dig('cc:license'))
            assert_equal(@event.license_classification.first.classification_aliases.first.uri, json_data.delete('cc:license'))

            assert_equal(@event.use_guidelines, json_data.delete('cc:useGuidlines'))
            assert_equal(@event.attribution_url, json_data.delete('cc:attributionUrl'))
            assert_equal(@event.attribution_name, json_data.delete('cc:attributionName'))
            assert_equal(@event.more_permissions, json_data.delete('cc:morePermissions'))
          end

          # linked default: images, organizer, performer
          assert_attributes(required_attributes, ['image', 'organizer', 'performer']) do
            assert_equal(@event.image.size, 1)
            assert_equal(json_data.dig('image').size, 1)
            assert_equal(@event.image.first.to_api_default_values, json_data.dig('image').first)
            json_data.delete('image')

            assert_equal(@event.organizer.size, 1)
            assert_equal(json_data.dig('organizer').size, 1)
            assert_equal(@event.organizer.first.to_api_default_values, json_data.dig('organizer').first)
            json_data.delete('organizer')

            assert_equal(@event.performer.size, 1)
            assert_equal(json_data.dig('performer').size, 1)
            assert_equal(@event.performer.first.to_api_default_values, json_data.dig('performer').first)
            json_data.delete('performer')
          end

          # embedded default: images, organizer, performer
          assert_attributes(required_attributes, ['offers']) do
            assert_equal(@event.offers.size, 1)
            assert_equal(json_data.dig('offers').size, 1)
            assert_equal(@event.offers.first.to_api_default_values, json_data.dig('offers').first)
            json_data.delete('offers')
          end

          # same_as => potentialAction
          assert_attributes(required_attributes, ['same_as']) do
            additional_property = json_data.dig('additionalProperty')
            assert(additional_property.size.positive?)
            same_as = additional_property.detect { |v| v.dig('identifier') == 'link' }
            assert_equal('PropertyValue', same_as.delete('@type'))
            assert_equal('link', same_as.delete('identifier'))
            assert_equal('Link', same_as.delete('name'))
            assert_equal(@event.same_as, same_as.delete('value'))
            assert_equal(0, same_as.size)
            json_data.delete('additionalProperty') if additional_property.reject(&:blank?).blank?
          end

          # embedded default: event_status, event_attendance_mode
          assert_attributes(required_attributes, ['event_status', 'event_attendance_mode']) do
            assert_equal(@event.event_status.first.classification_aliases.first.uri, json_data.delete('eventStatus'))
            assert_equal(@event.event_attendance_mode.first.classification_aliases.first.uri, json_data.delete('eventAttendanceMode'))
          end

          # embedded default: event_schedule
          assert_attributes(required_attributes, ['event_schedule']) do
            assert_equal(@event.event_schedule.size, 1)
            assert_equal(json_data.dig('eventSchedule').size, 1)
            assert_equal(@event.event_schedule.first.to_api_default_values, json_data.dig('eventSchedule').first)
            json_data.delete('eventSchedule')
          end

          # locations content_location, virtual_location
          assert_attributes(required_attributes, ['content_location', 'virtual_location']) do
            locations = json_data.dig('location')
            assert_equal(2, locations.size)
            content_location = locations.detect { |v| v.dig('@type') == 'TouristAttraction' }
            assert_equal(@event.content_location.first.to_api_default_values, content_location)

            virtual_location = locations.detect { |v| v.dig('@type') == 'VirtualLocation' }
            assert_equal(@event.virtual_location.first.to_api_default_values, virtual_location)
            json_data.delete('location')
          end

          # validate classifications
          event_classifications = @event.classification_aliases.to_a.select { |c| c.visible?('api') }.map(&:to_api_default_values).sort_by { |c| c['@id'] }
          json_classificatons = json_data.dig('dc:classification').sort_by { |c| c['@id'] }
          assert_equal(event_classifications, json_classificatons)
          json_data.delete('dc:classification')

          assert_equal([], required_attributes)
          assert_equal({}, json_data)
        end
      end
    end
  end
end
