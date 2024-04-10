# frozen_string_literal: true

require 'v4/base'

module DataCycleCore
  module Api
    module V4
      module Content
        class ThingTest < DataCycleCore::V4::Base
          before(:all) do
            @event = DataCycleCore::V4::DummyDataHelper.create_data('event')
            @thing_count = DataCycleCore::Thing.where(content_type: 'entity').count
          end

          test 'api/v4/thing default' do
            params = {
              id: @event.id
            }
            post api_v4_thing_path(params)

            json_data = response.parsed_body
            json_validate = json_data.dup.dig('@graph').first

            assert_context(json_data.dig('@context'), 'de')

            validator = DataCycleCore::V4::Validation::Thing.event
            assert_equal({}, validator.call(json_validate).errors.to_h)
          end

          test 'api/v4/thing with fields: startDate, endDate' do
            params = {
              id: @event.id,
              fields: 'startDate,endDate,description'
            }
            post api_v4_thing_path(params)

            json_data = response.parsed_body
            json_validate = json_data.dup.dig('@graph').first

            assert_context(json_data.dig('@context'), 'de')

            fields = Dry::Schema.JSON do
              required(:startDate).value(:date_time)
              required(:endDate).value(:date_time)
              optional(:description).value(:string)
            end

            validator = DataCycleCore::V4::Validation::Thing.event(params: { fields: })
            assert_equal({}, validator.call(json_validate).errors.to_h)
          end

          test 'api/v4/thing with fields: image,location' do
            params = {
              id: @event.id,
              fields: 'location,image'
            }
            post api_v4_thing_path(params)

            json_data = response.parsed_body
            json_validate = json_data.dup.dig('@graph').first

            assert_context(json_data.dig('@context'), 'de')

            fields = Dry::Schema.JSON do
              required(:image).value(:array, min_size?: 1).each do
                hash(DataCycleCore::V4::Validation::Thing::DEFAULT_HEADER)
              end
              required(:location).value(:array, min_size?: 1).each do
                hash(DataCycleCore::V4::Validation::Thing::DEFAULT_HEADER)
              end
            end

            validator = DataCycleCore::V4::Validation::Thing.event(params: { fields: })
            assert_equal({}, validator.call(json_validate).errors.to_h)
          end

          test 'api/v4/thing with fields: location,image.thumbnailUrl,eventSchedule.startDate,eventSchedule.endDate' do
            params = {
              id: @event.id,
              fields: 'location,image.thumbnailUrl,eventSchedule.startDate,eventSchedule.endDate'
            }
            post api_v4_thing_path(params)

            json_data = response.parsed_body
            json_validate = json_data.dup.dig('@graph').first

            assert_context(json_data.dig('@context'), 'de')

            fields = Dry::Schema.JSON do
              required(:image).value(:array, min_size?: 1).each do
                hash(
                  DataCycleCore::V4::Validation::Thing::DEFAULT_HEADER.merge(
                    Dry::Schema.JSON do
                      required(:thumbnailUrl).value(:string)
                    end
                  )
                )
              end
              required(:location).value(:array, min_size?: 1).each do
                hash(DataCycleCore::V4::Validation::Thing::DEFAULT_HEADER)
              end
              required(:eventSchedule).value(:array, min_size?: 1).each do
                hash(
                  Dry::Schema.JSON do
                    required(:@id).value(:uuid_v4?)
                    required(:@type).value(:string)
                    required(:startDate).value(:date_time)
                    required(:endDate).value(:date_time)
                  end
                )
              end
            end

            validator = DataCycleCore::V4::Validation::Thing.event(params: { fields: })
            assert_equal({}, validator.call(json_validate).errors.to_h)
          end

          test 'api/v4/thing with include=image.author fields:image.thumbnailUrl,description' do
            params = {
              id: @event.id,
              fields: 'image.thumbnailUrl,description',
              include: 'image.author'
            }
            post api_v4_thing_path(params)

            json_data = response.parsed_body
            json_validate = json_data.dup.dig('@graph').first

            assert_context(json_data.dig('@context'), 'de')

            fields = Dry::Schema.JSON do
              required(:description).value(:string)
              required(:image).value(:array, min_size?: 1).each do
                hash(
                  DataCycleCore::V4::Validation::Thing::DEFAULT_HEADER.merge(
                    Dry::Schema.JSON do
                      required(:thumbnailUrl).value(:string)
                      required(:author).value(:array, min_size?: 1).each do
                        hash(DataCycleCore::V4::Validation::Thing::DEFAULT_HEADER.merge(
                               DataCycleCore::V4::Validation::Thing::DEFAULT_PERSON_ATTRIBUTES
                             ))
                      end
                    end
                  )
                )
              end
            end

            validator = DataCycleCore::V4::Validation::Thing.event(params: { fields: })
            assert_equal({}, validator.call(json_validate).errors.to_h)
          end

          test 'api/v4/thing with include=organizer' do
            params = {
              id: @event.id,
              include: 'organizer'
            }
            post api_v4_thing_path(params)

            json_data = response.parsed_body
            json_validate = json_data.dup.dig('@graph').first

            assert_context(json_data.dig('@context'), 'de')

            include = Dry::Schema.JSON do
              required(:organizer).value(:array, min_size?: 1).each do
                hash(DataCycleCore::V4::Validation::Thing::DEFAULT_HEADER.merge(
                       DataCycleCore::V4::Validation::Thing::DEFAULT_PERSON_ATTRIBUTES
                     ))
              end
            end

            validator = DataCycleCore::V4::Validation::Thing.event(params: { include: })
            assert_equal({}, validator.call(json_validate).errors.to_h)
          end

          test 'api/v4/thing with fields:image.thumbnailUrl,description,image.author.address' do
            params = {
              id: @event.id,
              fields: 'image.thumbnailUrl,description,image.author.address'
            }
            post api_v4_thing_path(params)

            json_data = response.parsed_body
            json_validate = json_data.dup.dig('@graph').first

            assert_context(json_data.dig('@context'), 'de')

            fields = Dry::Schema.JSON do
              required(:description).value(:string)
              required(:image).value(:array, min_size?: 1).each do
                hash(
                  DataCycleCore::V4::Validation::Thing::DEFAULT_HEADER.merge(
                    Dry::Schema.JSON do
                      required(:thumbnailUrl).value(:string)
                      required(:author).value(:array, min_size?: 1).each do
                        hash(
                          DataCycleCore::V4::Validation::Thing::DEFAULT_HEADER.merge(
                            Dry::Schema.JSON do
                              required(:address).hash do
                                required(:@id).value(:uuid_v4?)
                                required(:@type).value(:string)
                                required(:streetAddress).value(:string)
                                required(:postalCode).value(:string)
                                required(:addressLocality).value(:string)
                                required(:addressCountry).value(:string)
                                required(:name).value(:string)
                                required(:telephone).value(:string)
                                required(:faxNumber).value(:string)
                                required(:email).value(:string)
                                required(:url).value(:string)
                              end
                            end
                          )
                        )
                      end
                    end
                  )
                )
              end
            end

            validator = DataCycleCore::V4::Validation::Thing.event(params: { fields: })
            assert_equal({}, validator.call(json_validate).errors.to_h)
          end

          test 'api/v4/thing width fields: image.thumbnailUrl,image.author.name,image.author.address,dc:classification.skos:prefLabel include: dc:classification.skos:inScheme' do
            params = {
              id: @event.id,
              fields: 'description,image.thumbnailUrl,image.author.givenName,image.author.familyName,image.author.address,dc:classification.skos:prefLabel',
              include: 'dc:classification.skos:inScheme'
            }
            post api_v4_thing_path(params)

            json_data = response.parsed_body
            json_validate = json_data.dup.dig('@graph').first

            assert_context(json_data.dig('@context'), 'de')

            fields = Dry::Schema.JSON do
              required(:'dc:classification').value(:array, min_size?: 1).each do
                hash(
                  DataCycleCore::V4::Validation::Concept::DEFAULT_HEADER.merge(
                    Dry::Schema.JSON do
                      required(:'skos:prefLabel').value(:string)
                      required(:'skos:inScheme').hash(
                        DataCycleCore::V4::Validation::Concept::DEFAULT_HEADER.merge(
                          DataCycleCore::V4::Validation::Concept::DEFAULT_CONCEPT_SCHEME_ATTRIBUTES
                        )
                      )
                    end
                  )
                )
              end
              required(:description).value(:string)
              required(:image).value(:array, min_size?: 1).each do
                hash(
                  DataCycleCore::V4::Validation::Thing::DEFAULT_HEADER.merge(
                    Dry::Schema.JSON do
                      required(:thumbnailUrl).value(:string)
                      required(:author).value(:array, min_size?: 1).each do
                        hash(
                          DataCycleCore::V4::Validation::Thing::DEFAULT_HEADER.merge(
                            Dry::Schema.JSON do
                              required(:givenName).value(:string)
                              required(:familyName).value(:string)
                              required(:address).hash do
                                required(:@id).value(:uuid_v4?)
                                required(:@type).value(:string)
                                required(:streetAddress).value(:string)
                                required(:postalCode).value(:string)
                                required(:addressLocality).value(:string)
                                required(:addressCountry).value(:string)
                                required(:name).value(:string)
                                required(:telephone).value(:string)
                                required(:faxNumber).value(:string)
                                required(:email).value(:string)
                                required(:url).value(:string)
                              end
                            end
                          )
                        )
                      end
                    end
                  )
                )
              end
            end

            validator = DataCycleCore::V4::Validation::Thing.event(params: { fields: })
            assert_equal({}, validator.call(json_validate).errors.to_h)
          end

          test 'api/v4/things endpoint with fields: image.thumbnailUrl,description,thumbnailUrl' do
            params = {
              page: {
                size: 100
              },
              fields: 'image.thumbnailUrl,description,thumbnailUrl'
            }
            post api_v4_things_path(params)
            assert_api_count_result(@thing_count)

            json_data = response.parsed_body

            assert_context(json_data.dig('@context'), 'de')

            fields = Dry::Schema.JSON do
              optional(:description).value(:string)
              optional(:thumbnailUrl).value(:string)
              optional(:image).value(:array).each do
                hash(
                  DataCycleCore::V4::Validation::Thing::DEFAULT_HEADER.merge(
                    Dry::Schema.JSON do
                      required(:thumbnailUrl).value(:string)
                    end
                  )
                )
              end
            end

            thing_with_description = false
            thing_with_thumbnail_url = false
            thing_with_image_thumbnail_url = false
            validator = DataCycleCore::V4::Validation::Thing.event(params: { fields: })
            json_data['@graph'].each do |item|
              assert_equal({}, validator.call(item).errors.to_h)
              thing_with_description = true if item.dig('description').present?
              thing_with_thumbnail_url = true if item.dig('thumbnailUrl').present?
              thing_with_image_thumbnail_url = true if item.dig('image')&.first&.dig('thumbnailUrl').present?
            end
            assert(thing_with_description)
            assert(thing_with_thumbnail_url)
            assert(thing_with_image_thumbnail_url)
          end

          test 'api/v4/things endpoint with fields: image.thumbnailUrl,description,thumbnailUrl,dc:classification.skosPreflabel include: dc:classification.skos:inScheme' do
            params = {
              page: {
                size: 100
              },
              fields: 'image.thumbnailUrl,description,thumbnailUrl,dc:classification.skos:prefLabel',
              include: 'dc:classification.skos:inScheme'
            }
            post api_v4_things_path(params)
            assert_api_count_result(@thing_count)

            json_data = response.parsed_body

            assert_context(json_data.dig('@context'), 'de')

            fields = Dry::Schema.JSON do
              optional(:'dc:classification').value(:array).each do
                hash(
                  DataCycleCore::V4::Validation::Concept::DEFAULT_HEADER.merge(
                    Dry::Schema.JSON do
                      required(:'skos:prefLabel').value(:string)
                      required(:'skos:inScheme').hash(
                        DataCycleCore::V4::Validation::Concept::DEFAULT_HEADER.merge(
                          DataCycleCore::V4::Validation::Concept::DEFAULT_CONCEPT_SCHEME_ATTRIBUTES
                        )
                      )
                    end
                  )
                )
              end
              optional(:description).value(:string)
              optional(:thumbnailUrl).value(:string)
              optional(:image).value(:array).each do
                hash(
                  DataCycleCore::V4::Validation::Thing::DEFAULT_HEADER.merge(
                    Dry::Schema.JSON do
                      required(:thumbnailUrl).value(:string)
                    end
                  )
                )
              end
            end

            thing_with_description = false
            thing_with_thumbnail_url = false
            thing_with_image_thumbnail_url = false
            thing_with_classifications_in_scheme = false
            thing_with_classifications_pref_label = false
            validator = DataCycleCore::V4::Validation::Thing.event(params: { fields: })
            json_data['@graph'].each do |item|
              assert_equal({}, validator.call(item).errors.to_h)
              thing_with_description = true if item.dig('description').present?
              thing_with_thumbnail_url = true if item.dig('thumbnailUrl').present?
              thing_with_image_thumbnail_url = true if item.dig('image')&.first&.dig('thumbnailUrl').present?
              thing_with_classifications_in_scheme = true if item.dig('dc:classification')&.first&.dig('skos:inScheme')&.dig('skos:prefLabel').present?
              thing_with_classifications_pref_label = true if item.dig('dc:classification')&.first&.dig('skos:prefLabel').present?
            end
            assert(thing_with_description)
            assert(thing_with_thumbnail_url)
            assert(thing_with_image_thumbnail_url)
            assert(thing_with_classifications_in_scheme)
            assert(thing_with_classifications_pref_label)
          end
        end
      end
    end
  end
end
