# frozen_string_literal: true

require 'v4/base'

module DataCycleCore
  module Api
    module V4
      class ThingData < DataCycleCore::V4::Base
        setup do
          @event = DataCycleCore::V4::DummyDataHelper.create_data('event')
        end

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
              'cc:useGuidlines' => @event.use_guidelines,
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

          # embedded default: images, organizer, performer
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

          # embedded default: event_status, event_attendance_mode
          assert_attributes(json_validate, required_attributes, ['event_status', 'event_attendance_mode']) do
            {
              'eventStatus' => @event.event_status.first.classification_aliases.first.uri,
              'eventAttendanceMode' => @event.event_attendance_mode.first.classification_aliases.first.uri
            }
          end

          # embedded default: event_schedule
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

          assert_classifications(json_validate, @event.classification_aliases.to_a.select { |c| c.visible?('api') }.map(&:to_api_default_values))

          assert_equal([], required_attributes)
          assert_equal({}, json_validate)
        end
      end
    end
  end
end
