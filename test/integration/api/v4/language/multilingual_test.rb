# frozen_string_literal: true

require 'v4/base'

module DataCycleCore
  module Api
    module V4
      module Language
        class MultilingualTest < DataCycleCore::V4::Base
          include DataCycleCore::ApiHelper

          before(:all) do
            @content = DataCycleCore::V4::DummyDataHelper.create_data('event')
            @article = DataCycleCore::V4::DummyDataHelper.create_data('structured_article')
            @article.set_data_hash(partial_update: true, prevent_history: true, data_hash: { about: [@content.id] })
            @content.reload
          end

          test 'api_v4_thing_path event multilingual in non existing language' do
            assert_full_thing_datahash(@content)
            params = {
              id: @content.id,
              language: 'en'
            }
            post api_v4_thing_path(params)
            json_data = response.parsed_body
            json_validate = json_data.dup.dig('@graph').first

            assert_context(json_data.dig('@context'), params.dig(:language))

            # required attributes for multilingual contents
            required_attributes = required_multilingual_validation_attributes(@content) + ['subject_of']

            assert_attributes(json_validate, required_attributes, ['id']) do
              {
                '@id' => @content.id,
                '@type' => @content.api_type,
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
                'url' => @content.attribution_url,
                'copyrightNotice' => @content.copyright_notice_computed
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
            assert_attributes(json_validate, required_attributes, ['image', 'organizer', 'performer', 'super_event', 'subject_of']) do
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
                ],
                'subjectOf' => [
                  @content.subject_of.first.to_api_default_values
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

            # potential_action
            assert_attributes(json_validate, required_attributes, ['potential_action']) do
              {
                'potentialAction' => [
                  @content.potential_action.first.to_api_default_values
                ]
              }
            end

            # locations content_location
            assert_attributes(json_validate, required_attributes, ['content_location']) do
              {
                'location' => [
                  @content.content_location.first.to_api_default_values
                ]
              }
            end

            assert_classifications(json_validate, @content.classification_aliases.to_a.select { |c| c.visible?('api') }.map(&:to_api_default_values))

            assert_equal([], required_attributes)
            assert_equal({}, json_validate)
          end

          test 'api_v4_thing_path event multilingual in non existing language with fallback to de' do
            assert_full_thing_datahash(@content)
            @content.reload
            params = {
              id: @content.id,
              language: 'de,en'
            }
            post api_v4_thing_path(params)
            json_data = response.parsed_body
            json_validate = json_data.dup.dig('@graph').first

            assert_context(json_data.dig('@context'), params.dig(:language))

            # test full event data
            required_attributes = required_validation_attributes(@content)

            # test minimal
            assert_attributes(json_validate, required_attributes, ['id']) do
              {
                '@id' => @content.id,
                '@type' => @content.api_type
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
            assert_translated_attributes(json_validate, required_attributes, ['name', 'description', 'url', 'dc:slug']) do
              {
                'description' => translated_value(@content, 'description', ['de']),
                'name' => translated_value(@content, 'name', ['de']),
                'sameAs' => translated_value(@content, 'url', ['de']),
                'dc:slug' => translated_value(@content, 'slug', ['de'])
              }
            end

            assert_attributes(json_validate, required_attributes, ['potential_action']) do
              {
                'potentialAction' => [
                  @content.potential_action.first.to_api_default_values
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
            assert_translated_attributes(json_validate, required_attributes, ['license', 'use_guidelines', 'attribution_url', 'attribution_name', 'license_classification']) do
              # license is overwritten by license_classification
              {
                'cc:license' => @content.license_classification.first.classification_aliases.first.uri,
                'cc:useGuidelines' => translated_value(@content, 'use_guidelines', ['de']),
                'url' => @content.attribution_url,
                'copyrightNotice' => @content.copyright_notice_computed
              }
            end

            # same_as => additionalProperty
            assert_translated_attributes(json_validate, required_attributes, ['same_as', 'feratel_content_score', 'content_score']) do
              {
                'additionalProperty' => [
                  {
                    '@id' => generate_uuid(@content.id, 'same_as'),
                    '@type' => 'PropertyValue',
                    'identifier' => 'link',
                    'value' => translated_value(@content, 'same_as', ['de']),
                    'name' => 'Link'
                  },
                  {
                    '@id' => generate_uuid(@content.id, 'feratel_content_score'),
                    '@type' => 'PropertyValue',
                    'identifier' => 'feratelContentScore',
                    'name' => 'ContentScore (Feratel)',
                    'value' => translated_value(@content, 'feratel_content_score', ['de'])
                  },
                  {
                    '@id' => generate_uuid(@content.id, 'content_score'),
                    '@type' => 'PropertyValue',
                    'identifier' => 'contentScore',
                    'name' => 'ContentScore',
                    'value' => translated_value(@content, 'content_score', ['de'])
                  }
                ]
              }
            end

            # linked default: images, organizer, performer
            assert_attributes(json_validate, required_attributes, ['image', 'organizer', 'performer', 'subject_of']) do
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
                'subjectOf' => [
                  @content.subject_of.first.to_api_default_values
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

          test 'api_v4_thing_path event multilingual in non existing language with translated and not translated linked' do
            # add translations
            # organizer -> Person
            organizer = @content.organizer.first
            data_hash_en = DataCycleCore::TestPreparations.load_dummy_data_hash('persons', 'v4_person_en')
            organizer.reload

            I18n.with_locale(:en) do
              organizer.set_data_hash(data_hash: organizer.get_data_hash.except(*organizer.computed_property_names).merge(data_hash_en))
            end

            assert_full_thing_datahash(@content)

            fields = [
              'name',
              'dc:multilingual',
              'dc:translation',
              'organizer.name',
              'organizer.dc:multilingual',
              'organizer.dc:translation',
              'image.name',
              'image.contentUrl',
              'image.dc:multilingual',
              'image.dc:translation'
            ]

            params = {
              id: @content.id,
              fields: fields.join(','),
              language: 'en'
            }
            post api_v4_thing_path(params)
            json_data = response.parsed_body
            json_validate = json_data.dup.dig('@graph').first

            assert_context(json_data.dig('@context'), params.dig(:language))

            # empty because of fields param
            required_attributes = []

            # test minimal
            assert_attributes(json_validate, required_attributes, ['id']) do
              {
                '@id' => @content.id,
                '@type' => @content.api_type
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

            # not translated image object
            # name = empty => translatable value
            # contentUrl = filled => not translatable value
            assert_translated_attributes(json_validate, required_attributes, ['image']) do
              {
                'image' => [
                  @content.image.first.to_api_default_values.merge(
                    {
                      'dc:multilingual' => true,
                      'dc:translation' => [
                        'de'
                      ],
                      'contentUrl' => DataCycleCore::Feature::ImageProxy.enabled? ? DataCycleCore::Feature::ImageProxy.process_image(content: @content.image.first, variant: 'default') : @content.image.first.content_url
                    }
                  )
                ]
              }
            end

            # translated author object
            # name => translatedValue
            assert_translated_attributes(json_validate, required_attributes, ['organizer']) do
              {
                'organizer' => [
                  @content.organizer.first.to_api_default_values.merge(
                    {
                      'dc:multilingual' => true,
                      'dc:translation' => [
                        'de',
                        'en'
                      ],
                      'name' => I18n.with_locale(:en) { @content.organizer.first.name }
                    }
                  )
                ]
              }
            end

            assert_equal([], required_attributes)
            assert_equal({}, json_validate)
          end

          test 'api_v4_thing_path event multilingual in non existing language, de fallback with translated and not translated linked' do
            # add translations
            # organizer -> Person
            organizer = @content.organizer.first
            data_hash_en = DataCycleCore::TestPreparations.load_dummy_data_hash('persons', 'v4_person_en')
            organizer.reload
            I18n.with_locale(:en) { organizer.set_data_hash(data_hash: organizer.get_data_hash.except(*organizer.computed_property_names).merge(data_hash_en)) }

            assert_full_thing_datahash(@content)

            fields = [
              'name',
              'dc:multilingual',
              'dc:translation',
              'organizer.name',
              'organizer.dc:multilingual',
              'organizer.dc:translation',
              'image.name',
              'image.contentUrl',
              'image.dc:multilingual',
              'image.dc:translation'
            ]

            params = {
              id: @content.id,
              fields: fields.join(','),
              language: 'en,de'
            }
            post api_v4_thing_path(params)
            json_data = response.parsed_body
            json_validate = json_data.dup.dig('@graph').first

            assert_context(json_data.dig('@context'), params.dig(:language))

            # empty because of fields param
            required_attributes = []

            # test minimal
            assert_attributes(json_validate, required_attributes, ['id']) do
              {
                '@id' => @content.id,
                '@type' => @content.api_type
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
            assert_translated_attributes(json_validate, required_attributes, ['name']) do
              {
                'name' => translated_value(@content, 'name', ['de'])
              }
            end

            # not translated image object
            # name = translatable value
            # contentUrl = not translatable value
            assert_translated_attributes(json_validate, required_attributes, ['image']) do
              {
                'image' => [
                  @content.image.first.to_api_default_values.merge(
                    {
                      'dc:multilingual' => true,
                      'dc:translation' => [
                        'de'
                      ],
                      'name' => translated_value(@content, 'image.first.name', ['de']),
                      'contentUrl' => DataCycleCore::Feature::ImageProxy.enabled? ? DataCycleCore::Feature::ImageProxy.process_image(content: @content.image.first, variant: 'default') : @content.image.first.content_url
                    }
                  )
                ]
              }
            end

            # translated author object
            # name => translatedValue
            assert_translated_attributes(json_validate, required_attributes, ['organizer']) do
              {
                'organizer' => [
                  @content.organizer.first.to_api_default_values.merge(
                    {
                      'dc:multilingual' => true,
                      'dc:translation' => [
                        'de',
                        'en'
                      ],
                      'name' => translated_value(@content, 'organizer.first.name', ['de', 'en'])
                    }
                  )
                ]
              }
            end

            assert_equal([], required_attributes)
            assert_equal({}, json_validate)
          end

          test 'api_v4_thing_path translated event for de,en' do
            data_hash_en = DataCycleCore::TestPreparations.load_dummy_data_hash('events', 'v4_event_en')
            offer = @content.offers.first
            offer_data_hash_en = DataCycleCore::TestPreparations.load_dummy_data_hash('intangibles', 'v4_offer_en').merge({ 'id' => offer.id })
            data_hash_en['offers'] = [offer_data_hash_en]

            I18n.with_locale(:en) { @content.set_data_hash(data_hash: @content.get_data_hash.merge(data_hash_en)) }
            @content.reload

            assert_translated_datahash(data_hash_en, @content)
            assert_translated_thing(@content, 'en')
            assert_full_thing_datahash(@content)

            params = {
              id: @content.id,
              language: 'de,en'
            }
            post api_v4_thing_path(params)
            json_data = response.parsed_body
            json_validate = json_data.dup.dig('@graph').first

            assert_context(json_data.dig('@context'), params.dig(:language))

            # test full event data
            required_attributes = required_validation_attributes(@content)

            # test minimal
            assert_attributes(json_validate, required_attributes, ['id']) do
              {
                '@id' => @content.id,
                '@type' => @content.api_type
              }
            end

            # validate language
            assert_attributes(json_validate, required_attributes, []) do
              {
                'dc:multilingual' => true,
                'dc:translation' => [
                  'de',
                  'en'
                ]
              }
            end

            # plain attributes without transformation
            assert_translated_attributes(json_validate, required_attributes, ['name', 'description', 'url', 'dc:slug']) do
              {
                'description' => translated_value(@content, 'description', ['de', 'en']),
                'name' => translated_value(@content, 'name', ['de', 'en']),
                'sameAs' => translated_value(@content, 'url', ['de', 'en']),
                'dc:slug' => translated_value(@content, 'slug', ['de', 'en'])
              }
            end

            assert_attributes(json_validate, required_attributes, ['potential_action']) do
              {
                'potentialAction' => [
                  @content.potential_action.first.to_api_default_values
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
            assert_translated_attributes(json_validate, required_attributes, ['license', 'use_guidelines', 'attribution_url', 'attribution_name', 'license_classification']) do
              # license is overwritten by license_classification
              {
                'cc:license' => @content.license_classification.first.classification_aliases.first.uri,
                'cc:useGuidelines' => translated_value(@content, 'use_guidelines', ['de', 'en']),
                'url' => @content.attribution_url,
                'copyrightNotice' => @content.copyright_notice_computed
              }
            end

            # same_as => additionalProperty
            assert_translated_attributes(json_validate, required_attributes, ['same_as', 'feratel_content_score', 'content_score']) do
              {
                'additionalProperty' => [
                  {
                    '@id' => generate_uuid(@content.id, 'same_as'),
                    '@type' => 'PropertyValue',
                    'identifier' => 'link',
                    'value' => translated_value(@content, 'same_as', ['de', 'en']),
                    'name' => 'Link'
                  },
                  {
                    '@id' => generate_uuid(@content.id, 'feratel_content_score'),
                    '@type' => 'PropertyValue',
                    'identifier' => 'feratelContentScore',
                    'name' => 'ContentScore (Feratel)',
                    'value' => translated_value(@content, 'feratel_content_score', ['de', 'en'])
                  },
                  {
                    '@id' => generate_uuid(@content.id, 'content_score'),
                    '@type' => 'PropertyValue',
                    'identifier' => 'contentScore',
                    'name' => 'ContentScore',
                    'value' => translated_value(@content, 'content_score', ['de', 'en'])
                  }
                ]
              }
            end

            # linked default: images, organizer, performer
            assert_attributes(json_validate, required_attributes, ['image', 'organizer', 'performer', 'subject_of']) do
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
                'subjectOf' => [
                  @content.subject_of.first.to_api_default_values
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

            # locations content_location, virtual_location (expected 2 virtual_locations because of non translated embedded)
            assert_linked(json_validate, required_attributes, ['content_location', 'virtual_location']) do
              {
                'location' => [
                  @content.content_location.first.to_api_default_values,
                  @content.virtual_location.first.to_api_default_values,
                  I18n.with_locale(:en) { @content.virtual_location.last.to_api_default_values }
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

          test 'api_v4_thing_path translated event for only en with linked and embedded translations' do
            # add translations
            # organizer -> Person
            organizer = @content.organizer.first
            data_hash_en = DataCycleCore::TestPreparations.load_dummy_data_hash('persons', 'v4_person_en')
            organizer.reload
            I18n.with_locale(:en) { organizer.set_data_hash(data_hash: organizer.get_data_hash.except(*organizer.computed_property_names).merge(data_hash_en)) }

            data_hash_en = DataCycleCore::TestPreparations.load_dummy_data_hash('events', 'v4_event_en')
            offer = @content.offers.first
            offer_data_hash_en = DataCycleCore::TestPreparations.load_dummy_data_hash('intangibles', 'v4_offer_en').merge({ 'id' => offer.id })
            data_hash_en['offers'] = [offer_data_hash_en]
            @content.reload
            I18n.with_locale(:en) { @content.set_data_hash(data_hash: @content.get_data_hash.merge(data_hash_en)) }

            assert_translated_datahash(data_hash_en, @content)
            assert_translated_thing(@content, 'en')
            assert_full_thing_datahash(@content)

            # image not translated
            # organizer translated
            # offers translated embedded
            # location => virtualLocation = not translated embedded
            fields = [
              'name',
              'dc:multilingual',
              'dc:translation',
              'organizer.name',
              'organizer.dc:multilingual',
              'organizer.dc:translation',
              'image.name',
              'image.dc:multilingual',
              'image.dc:translation',
              'offers.name',
              'offers.dc:multilingual',
              'offers.dc:translation',
              'location.name',
              'location.dc:multilingual',
              'location.dc:translation',
              'subjectOf.name',
              'subjectOf.dc:multilingual',
              'subjectOf.dc:translation'
            ]

            params = {
              id: @content.id,
              fields: fields.join(','),
              language: 'en'
            }

            post api_v4_thing_path(params)
            json_data = response.parsed_body
            json_validate = json_data.dup.dig('@graph').first

            assert_context(json_data.dig('@context'), params.dig(:language))

            # empty because of fields param
            required_attributes = []

            # test minimal
            assert_attributes(json_validate, required_attributes, ['id']) do
              {
                '@id' => @content.id,
                '@type' => @content.api_type
              }
            end

            # validate language
            assert_attributes(json_validate, required_attributes, []) do
              {
                'dc:multilingual' => true,
                'dc:translation' => [
                  'de',
                  'en'
                ]
              }
            end

            # plain attributes without transformation
            assert_translated_attributes(json_validate, required_attributes, ['name']) do
              {
                'name' => I18n.with_locale(:en) { @content.name }
              }
            end

            # not translated image object
            # name = translatable value
            # contentUrl = not translatable value
            assert_translated_attributes(json_validate, required_attributes, ['image']) do
              {
                'image' => [
                  @content.image.first.to_api_default_values.merge(
                    {
                      'dc:multilingual' => true,
                      'dc:translation' => [
                        'de'
                      ]
                    }
                  )
                ]
              }
            end

            # translated author object
            # name => translatedValue
            assert_translated_attributes(json_validate, required_attributes, ['organizer']) do
              {
                'organizer' => [
                  @content.organizer.first.to_api_default_values.merge(
                    {
                      'dc:multilingual' => true,
                      'dc:translation' => [
                        'de',
                        'en'
                      ],
                      'name' => I18n.with_locale(:en) { @content.organizer.first.name }
                    }
                  )
                ]
              }
            end

            assert_translated_attributes(json_validate, required_attributes, ['offers']) do
              {
                'offers' => [
                  @content.offers.first.to_api_default_values.merge(
                    {
                      'dc:multilingual' => true,
                      'dc:translation' => [
                        'de',
                        'en'
                      ],
                      'name' => I18n.with_locale(:en) { @content.offers.first.name }
                    }
                  )
                ]
              }
            end

            # locations content_location, virtual_location (expected 2 virtual_locations because of non translated embedded)
            assert_linked(json_validate, required_attributes, ['content_location', 'virtual_location']) do
              {
                'location' => [
                  @content.content_location.first.to_api_default_values.merge(
                    {
                      'dc:multilingual' => true,
                      'dc:translation' => [
                        'de'
                      ]
                    }
                  ),
                  @content.virtual_location.first.to_api_default_values.merge(
                    {
                      'dc:multilingual' => false,
                      'dc:translation' => [
                        'de'
                      ]
                    }
                  ),
                  I18n.with_locale(:en) do
                    @content.virtual_location.last.to_api_default_values.merge(
                      {
                        'dc:multilingual' => false,
                        'dc:translation' => [
                          'en'
                        ],
                        'name' => @content.virtual_location.last.name
                      }
                    )
                  end
                ]
              }
            end

            assert_translated_attributes(json_validate, required_attributes, ['subject_of']) do
              {
                'subjectOf' => [
                  @content.subject_of.first.to_api_default_values.merge(
                    {
                      'dc:multilingual' => false,
                      'dc:translation' => [
                        'de'
                      ]
                    }
                  )
                ]
              }
            end

            assert_equal([], required_attributes)
            assert_equal({}, json_validate)
          end

          test 'api_v4_thing_path translated event for de,en with linked and embedded translations' do
            # add translations
            # organizer -> Person
            organizer = @content.organizer.first
            data_hash_en = DataCycleCore::TestPreparations.load_dummy_data_hash('persons', 'v4_person_en')
            organizer.reload
            I18n.with_locale(:en) { organizer.set_data_hash(data_hash: organizer.get_data_hash.except(*organizer.computed_property_names).merge(data_hash_en)) }

            data_hash_en = DataCycleCore::TestPreparations.load_dummy_data_hash('events', 'v4_event_en')
            offer = @content.offers.first
            offer_data_hash_en = DataCycleCore::TestPreparations.load_dummy_data_hash('intangibles', 'v4_offer_en').merge({ 'id' => offer.id })
            data_hash_en['offers'] = [offer_data_hash_en]
            @content.reload
            I18n.with_locale(:en) { @content.set_data_hash(data_hash: @content.get_data_hash.merge(data_hash_en)) }

            assert_translated_datahash(data_hash_en, @content)
            assert_translated_thing(@content, 'en')
            assert_full_thing_datahash(@content)

            # image not translated
            # organizer translated
            # offers translated embedded
            # location => virtualLocation = not translated embedded
            fields = [
              'name',
              'dc:multilingual',
              'dc:translation',
              'organizer.name',
              'organizer.dc:multilingual',
              'organizer.dc:translation',
              'image.name',
              'image.dc:multilingual',
              'image.dc:translation',
              'offers.name',
              'offers.dc:multilingual',
              'offers.dc:translation',
              'location.name',
              'location.dc:multilingual',
              'location.dc:translation',
              'subjectOf.name',
              'subjectOf.dc:multilingual',
              'subjectOf.dc:translation'
            ]

            params = {
              id: @content.id,
              fields: fields.join(','),
              language: 'en,de'
            }

            post api_v4_thing_path(params)
            json_data = response.parsed_body
            json_validate = json_data.dup.dig('@graph').first

            assert_context(json_data.dig('@context'), params.dig(:language))

            # empty because of fields param
            required_attributes = []

            # test minimal
            assert_attributes(json_validate, required_attributes, ['id']) do
              {
                '@id' => @content.id,
                '@type' => @content.api_type
              }
            end

            # validate language
            assert_attributes(json_validate, required_attributes, []) do
              {
                'dc:multilingual' => true,
                'dc:translation' => [
                  'de',
                  'en'
                ]
              }
            end

            # plain attributes without transformation
            assert_translated_attributes(json_validate, required_attributes, ['name']) do
              {
                'name' => translated_value(@content, 'name', ['de', 'en'])
              }
            end

            # not translated image object
            # name = translatable value
            # contentUrl = not translatable value
            assert_translated_attributes(json_validate, required_attributes, ['image']) do
              {
                'image' => [
                  @content.image.first.to_api_default_values.merge(
                    {
                      'dc:multilingual' => true,
                      'dc:translation' => [
                        'de'
                      ],
                      'name' => translated_value(@content, 'image.first.name', ['de'])
                    }
                  )
                ]
              }
            end

            # translated author object
            # name => translatedValue
            assert_translated_attributes(json_validate, required_attributes, ['organizer']) do
              {
                'organizer' => [
                  @content.organizer.first.to_api_default_values.merge(
                    {
                      'dc:multilingual' => true,
                      'dc:translation' => [
                        'de',
                        'en'
                      ],
                      'name' => translated_value(@content, 'organizer.first.name', ['de', 'en'])
                    }
                  )
                ]
              }
            end

            assert_translated_attributes(json_validate, required_attributes, ['offers']) do
              {
                'offers' => [
                  @content.offers.first.to_api_default_values.merge(
                    {
                      'dc:multilingual' => true,
                      'dc:translation' => [
                        'de',
                        'en'
                      ],
                      'name' => translated_value(@content, 'offers.first.name', ['de', 'en'])
                    }
                  )
                ]
              }
            end

            # locations content_location, virtual_location (expected 2 virtual_locations because of non translated embedded)
            assert_linked(json_validate, required_attributes, ['content_location', 'virtual_location']) do
              {
                'location' => [
                  @content.content_location.first.to_api_default_values.merge(
                    {
                      'dc:multilingual' => true,
                      'dc:translation' => [
                        'de'
                      ],
                      'name' => translated_value(@content, 'content_location.first.name', ['de'])
                    }
                  ),
                  @content.virtual_location.first.to_api_default_values.merge(
                    {
                      'dc:multilingual' => false,
                      'dc:translation' => [
                        'de'
                      ],
                      'name' => translated_value(@content, 'virtual_location.first.name', ['de'])
                    }
                  ),
                  I18n.with_locale(:en) { @content.virtual_location.last.to_api_default_values }.merge(
                    {
                      'dc:multilingual' => false,
                      'dc:translation' => [
                        'en'
                      ],
                      'name' => translated_value(@content, 'virtual_location.last.name', ['en'])
                    }
                  )
                ]
              }
            end

            assert_translated_attributes(json_validate, required_attributes, ['subject_of']) do
              {
                'subjectOf' => [
                  @content.subject_of.first.to_api_default_values.merge(
                    {
                      'dc:multilingual' => false,
                      'dc:translation' => [
                        'de'
                      ],
                      'name' => translated_value(@content, 'subject_of.first.name', ['de'])
                    }
                  )
                ]
              }
            end

            assert_equal([], required_attributes)
            assert_equal({}, json_validate)
          end
        end
      end
    end
  end
end
