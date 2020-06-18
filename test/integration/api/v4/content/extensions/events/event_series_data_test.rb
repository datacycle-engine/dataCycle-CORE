# frozen_string_literal: true

require 'v4/base'

module DataCycleCore
  module Api
    module V4
      module Content
        module Extensions
          module Events
            class EventSeriesDataTest < DataCycleCore::V4::Base
              setup do
                @content = DataCycleCore::V4::DummyDataHelper.create_data('event_series')
              end

              test 'api_v4_thing_path validate full event series with default params' do
                assert_full_thing_datahash(@content)

                params = {
                  id: @content.id
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
                required_attributes = required_validation_attributes(@content)
                # test minimal

                assert_attributes(json_validate, required_attributes, ['id', 'name']) do
                  {
                    '@id' => @content.id,
                    '@type' => 'EventSeries',
                    'name' => @content.name
                  }
                end

                # plain attributes without transformation
                assert_attributes(json_validate, required_attributes, ['description', 'potential_action']) do
                  {
                    'description' => @content.description,
                    'potentialAction' => [
                      {
                        '@type' => 'https://schema.org/ViewAction',
                        'name' => 'potential_action',
                        'url' => @content.potential_action
                      }
                    ]
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
                    'cc:license' => @content.license_classification.first.classification_aliases.first.uri,
                    'cc:useGuidelines' => @content.use_guidelines,
                    'cc:attributionUrl' => @content.attribution_url,
                    'cc:attributionName' => @content.attribution_name,
                    'cc:morePermissions' => @content.more_permissions
                  }
                end

                # linked default: images, member
                assert_attributes(json_validate, required_attributes, ['image']) do
                  {
                    'image' => [
                      @content.image.first.to_api_default_values
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

                # locations content_location, virtual_location
                assert_attributes(json_validate, required_attributes, ['content_location', 'virtual_location']) do
                  {
                    'location' => [
                      @content.content_location.first.to_api_default_values,
                      @content.virtual_location.first.to_api_default_values
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
  end
end
