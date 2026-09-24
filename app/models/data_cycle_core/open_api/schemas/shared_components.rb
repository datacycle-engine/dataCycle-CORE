# frozen_string_literal: true

module DataCycleCore
  module OpenApi
    module Schemas
      # Recurring schema.org building blocks, defined once as OpenAPI 3.1
      # components/schemas and referenced everywhere via $ref
      # (analogous to the shared .jb partials of the v4 API).
      #
      # Source of truth per block (v4 partials / models):
      #   EntityReference  -> attributes/_linked.jb (stub: [['@id'], ['@type']])
      #   Concept          -> api_base/_classification.jb (skos:Concept)
      #   GeoCoordinates   -> api/v1/api_base/_geo.json.jbuilder / poi test
      #   GeoShape         -> api_base/_classification.jb (geoshape_as_json)
      #   Schedule         -> Schedule#to_schedule_schema_org
      #   OpeningHours...  -> attributes/_embedded_opening_hours_specification.jb
      #   PropertyValue    -> attributes/_property_value.jb + _property_value_header.jb
      #   Timeseries...    -> attributes/_timeseries.jb
      #   CollectionRef... -> attributes/_collection.jb
      #
      # Split across SharedComponents::References (plain reference/value
      # blocks + shared primitives), SharedComponents::Classification (Concept /
      # ConceptScheme), SharedComponents::Geo (GeoCoordinates / GeoShape) and
      # SharedComponents::Temporal (Schedule / OpeningHoursSpecification) for
      # readability; all four are extended in so their methods are plain
      # SharedComponents.* module methods, same as Localizable's `t`.
      module SharedComponents
        module_function

        extend DataCycleCore::OpenApi::Localizable
        extend DataCycleCore::OpenApi::Schemas::SharedComponents::References
        extend DataCycleCore::OpenApi::Schemas::SharedComponents::Classification
        extend DataCycleCore::OpenApi::Schemas::SharedComponents::Geo
        extend DataCycleCore::OpenApi::Schemas::SharedComponents::Temporal

        # Names of all shared building-block schemas. Authoritative source used
        # by EntityBuilder to decide when a property type maps to a shared $ref.
        NAMES = [
          'EntityReference', 'AssetReference', 'Concept', 'ConceptScheme', 'GeoCoordinates', 'GeoShape', 'Schedule', 'OpeningHoursSpecification', 'PropertyValue', 'TimeseriesReference', 'CollectionReference'
        ].freeze

        # @return [Hash{String=>Hash}] name => OpenAPI 3.1 schema object,
        #   ready to be merged into components/schemas.
        def all
          {
            'EntityReference' => entity_reference,
            'AssetReference' => asset_reference,
            'Concept' => concept,
            'ConceptScheme' => concept_scheme,
            'GeoCoordinates' => geo_coordinates,
            'GeoShape' => geo_shape,
            'Schedule' => schedule,
            'OpeningHoursSpecification' => opening_hours_specification,
            'PropertyValue' => property_value,
            'TimeseriesReference' => timeseries_reference,
            'CollectionReference' => collection_reference
          }
        end
      end
    end
  end
end
