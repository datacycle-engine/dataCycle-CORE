# frozen_string_literal: true

module DataCycleCore
  module V4
    module Validation
      class Thing
        DEFAULT_HEADER = Dry::Schema.JSON do
          required(:@id).value(:uuid_v4?)
          required(:@type) { array? | str? }
          optional(:name).value(:string)
        end

        DEFAULT_DELETED_HEADER = Dry::Schema.JSON do
          required(:@id).value(:uuid_v4?)
          required(:'dct:deleted').value(:date_time)
        end

        IDENTIFIER_ATTRIBUTES = Dry::Schema.JSON do
          required(:'@type').value(:string)
          required(:propertyID).value(:string)
          required(:value).value(:string)
        end

        # Test with Event
        DEFAULT_EVENT_ATTRIBUTES = Dry::Schema.JSON do
          optional(:'dc:multilingual').value(:bool)
          optional(:'dc:translation').array(:str?)
          optional(:"dc:classification").value(:array).each do
            hash(DataCycleCore::V4::Validation::Concept::DEFAULT_HEADER)
          end
          required(:startDate).value(:date_time)
          required(:endDate).value(:date_time)
          optional(:description).value(:string)
          optional(:sameAs).value(:string)
          optional(:eventAttendanceMode).value(:string)
          optional(:eventStatus).value(:string)
          optional(:image).value(:array).each do
            hash(DEFAULT_HEADER)
          end
          optional(:location).value(:array).each do
            hash(DEFAULT_HEADER)
          end
          optional(:performer).value(:array).each do
            hash(DEFAULT_HEADER)
          end
          optional(:organizer).value(:array).each do
            hash(DEFAULT_HEADER)
          end
          required(:eventSchedule).value(:array, min_size?: 1).each do
            hash do
              required(:@id).value(:uuid_v4?)
              required(:@type).value(:string)
            end
          end
          optional(:additionalProperty).value(:array).each do
            hash do
              required(:@type).value(:string)
              required(:identifier).value(:string)
              required(:name).value(:string)
              required(:value).value(:filled?)
            end
          end
          optional(:offers).value(:array).each do
            hash(DEFAULT_HEADER)
          end
          optional(:superEvent).value(:array).each do
            hash(DEFAULT_HEADER)
          end
          optional(:potentialAction).value(:array).each do
            hash do
              required(:@type).value(:string)
              required(:name).value(:string)
              required(:url).value(:string)
            end
          end
          optional(:'cc:license').value(:string)
<<<<<<< HEAD
          optional(:'cc:morePermissions').value(:string)
          optional(:'cc:attributionName').value(:string)
          optional(:'cc:attributionUrl').value(:string)
=======
          optional(:copyrightNotice).value(:string)
          optional(:url).value(:string)
>>>>>>> old/develop
          optional(:'cc:useGuidelines').value(:string)
          optional(:'dc:slug').value(:string)
        end

        # Test with Author
        DEFAULT_PERSON_ATTRIBUTES = Dry::Schema.JSON do
          optional(:'dc:multilingual').value(:bool)
          optional(:'dc:translation').array(:str?)
          optional(:"dc:classification").value(:array).each do
            hash(DataCycleCore::V4::Validation::Concept::DEFAULT_HEADER)
          end
          required(:givenName).value(:string)
          required(:familyName).value(:string)
          required(:honorificPrefix).value(:string)
          required(:honorificSuffix).value(:string)
          required(:jobTitle).value(:string)
          required(:description).value(:string)
          required(:address).hash do
            required(:'@type').value(:string)
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
          optional(:image).value(:array).each do
            hash(DEFAULT_HEADER)
          end
          optional(:memberOf).value(:array).each do
            hash(DEFAULT_HEADER)
          end
          optional(:'cc:license').value(:string)
<<<<<<< HEAD
          optional(:'cc:morePermissions').value(:string)
          optional(:'cc:attributionName').value(:string)
          optional(:'cc:attributionUrl').value(:string)
=======
          optional(:copyrightNotice).value(:string)
          optional(:url).value(:string)
>>>>>>> old/develop
          optional(:'cc:useGuidelines').value(:string)
          optional(:'dc:slug').value(:string)
        end

        def self.build_thing_validation(fields, include)
          return fields if fields.present?
          return DEFAULT_THING_ATTRIBUTES.merge(include) if include.present?
          DEFAULT_THING_ATTRIBUTES
        end

        def self.build_event_validation(fields, include)
          return fields if fields.present?
          return DEFAULT_EVENT_ATTRIBUTES.merge(include) if include.present?
          DEFAULT_EVENT_ATTRIBUTES
        end

        def self.thing(params: {})
          fields = params.dig(:fields)
          include = params.dig(:include)
          attributes = build_thing_validation(fields, include)
          validator = Dry::Validation.Contract do
            config.validate_keys = true
            json(DEFAULT_HEADER, attributes)
          end
          validator
        end

        def self.deleted_thing
          validator = Dry::Validation.Contract do
            config.validate_keys = true
            json(DEFAULT_DELETED_HEADER)
          end
          validator
        end

        def self.event(params: {})
          fields = params.dig(:fields)
          include = params.dig(:include)
          attributes = build_event_validation(fields, include)
          validator = Dry::Validation.Contract do
            config.validate_keys = true
            json(DEFAULT_HEADER, attributes)
          end
          validator
        end
      end
    end
  end
end
