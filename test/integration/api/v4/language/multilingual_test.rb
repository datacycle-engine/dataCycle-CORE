# frozen_string_literal: true

require 'v4/base'

module DataCycleCore
  module Api
    module V4
      module Language
        class MultilingualTest < DataCycleCore::V4::Base
          setup do
            @content = DataCycleCore::V4::DummyDataHelper.create_data('event')
            # add translation for image
            # author = @content.author.first
            # data_hash_en = DataCycleCore::TestPreparations.load_dummy_data_hash('persons', 'v4_person_en')
            # I18n.with_locale(:en) { author.set_data_hash(data_hash: author.get_data_hash.merge(data_hash_en)) }
            # author.reload
          end

          test 'api_v4_thing_path event multilingual in non existing language' do
            assert_full_thing_datahash(@content)

            params = {
              id: @content.id,
              language: 'en'
            }
            post api_v4_thing_path(params)
            json_data = JSON.parse response.body
            json_validate = json_data.dup

            # validate context
            json_context = json_validate.delete('@context')
            assert_equal(2, json_context.size)
            assert_equal('http://schema.org', json_context.first)
            validator = DataCycleCore::V4::Validation::Context.context(params.dig(:language))
            assert_equal({}, validator.call(json_context.second).errors.to_h)

            # required attributes for multilingual contents
            required_attributes = required_multilingual_validation_attributes(@content)

            assert_attributes(json_validate, required_attributes, ['id']) do
              {
                '@id' => @content.id,
                '@type' => 'Event',
                'dc:multilingual' => true,
                'dc:translation' => [
                  'de'
                ]
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
            assert_attributes(json_validate, required_attributes, ['license', 'attribution_url', 'attribution_name', 'more_permissions', 'license_classification']) do
              # license is overwritten by license_classification
              {
                'cc:license' => @content.license_classification.first.classification_aliases.first.uri,
                'cc:attributionUrl' => @content.attribution_url,
                'cc:attributionName' => @content.attribution_name,
                'cc:morePermissions' => @content.more_permissions
              }
            end

            # transformed classifications: event_status, event_attendance_mode
            assert_attributes(json_validate, required_attributes, ['event_status', 'event_attendance_mode']) do
              {
                'eventStatus' => @content.event_status.first.classification_aliases.first.uri,
                'eventAttendanceMode' => @content.event_attendance_mode.first.classification_aliases.first.uri
              }
            end

            # linked default
            assert_attributes(json_validate, required_attributes, ['image', 'organizer', 'performer', 'super_event']) do
              {
                'image' => [
                  @content.image.first.to_api_default_values
                ],
                'organizer' => [
                  @content.organizer.first.to_api_default_values
                ],
                'performer' => [
                  @content.performer.first.to_api_default_values
                ],
                'superEvent' => [
                  @content.super_event.first.to_api_default_values
                ]
              }
            end

            # embedded default:offer =translatable embedded
            assert_attributes(json_validate, required_attributes, ['offers']) do
              {
                'offers' => [
                  @content.offers.first.to_api_default_values
                ]
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

            # locations content_location, virtual_location=not translatable embedded
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
