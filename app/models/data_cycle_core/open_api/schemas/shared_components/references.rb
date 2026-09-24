# frozen_string_literal: true

module DataCycleCore
  module OpenApi
    module Schemas
      module SharedComponents
        # Small reusable primitives plus the plain reference/value building
        # blocks (EntityReference, AssetReference, PropertyValue,
        # TimeseriesReference, CollectionReference). Extended into
        # SharedComponents so its methods are available as
        # SharedComponents.* module methods (mirrors Localizable).
        module References
          # JSON-LD '@id' reference (a UUID string), shared by every schema block.
          def id_property
            { 'type' => 'string', 'format' => 'uuid' }
          end

          # JSON-LD '@type' as an array of type strings with a localized description
          # (the multi-type entity/collection reference header).
          def type_names_property(description_key)
            {
              'type' => 'array',
              'items' => { 'type' => 'string' },
              'description' => t(description_key)
            }
          end

          # oneOf [ scalar, [ { @language, @value } ] ] — the standard v4 shape
          # for a translatable value (see dc:translation / expand_language).
          def translatable_value(scalar_type: 'string', **scalar_opts)
            {
              'oneOf' => [
                { 'type' => scalar_type, **scalar_opts.transform_keys(&:to_s) },
                {
                  'type' => 'array',
                  'items' => {
                    'type' => 'object',
                    'properties' => {
                      '@language' => { 'type' => 'string' },
                      '@value' => { 'type' => scalar_type }
                    },
                    'required' => ['@language', '@value']
                  }
                }
              ]
            }
          end

          # Minimal stub emitted for linked/asset entities when not expanded via
          # include/fields: { '@id', '@type' }.
          def entity_reference
            {
              'type' => 'object',
              'title' => 'EntityReference',
              'description' => t('schemas.entity_reference'),
              'properties' => {
                '@id' => id_property,
                '@type' => type_names_property('schemas.type_hierarchy')
              },
              'required' => ['@id', '@type']
            }
          end

          # Asset reference emitted for asset properties (attributes/_asset.jb):
          # only { '@id' }, no @type — unlike EntityReference (linked stubs).
          def asset_reference
            {
              'type' => 'object',
              'title' => 'AssetReference',
              'description' => t('schemas.asset_reference'),
              'properties' => {
                '@id' => id_property
              },
              'required' => ['@id']
            }
          end

          # schema.org PropertyValue / QuantitativeValue (number + unit).
          def property_value
            {
              'type' => 'object',
              'title' => 'PropertyValue',
              'properties' => {
                '@id' => id_property,
                '@type' => { 'type' => 'string', 'description' => t('schemas.property_value_type') },
                'identifier' => { 'type' => 'string' },
                'name' => { 'type' => 'string' },
                'value' => {},
                'valueReference' => { 'type' => 'string', 'description' => t('schemas.property_value_value_reference') },
                'propertyID' => { 'type' => 'string' },
                'unitCode' => { 'type' => 'string' },
                'unitText' => { 'type' => 'string' },
                'minValue' => { 'type' => 'number' },
                'maxValue' => { 'type' => 'number' }
              },
              'required' => ['@type']
            }
          end

          # Pointer to a timeseries endpoint per attributes/_timeseries.jb.
          def timeseries_reference
            {
              'type' => 'object',
              'title' => 'TimeseriesReference',
              'properties' => {
                '@type' => { 'type' => 'string', 'const' => 'dc:timeseries' },
                'dc:entityUrl' => { 'type' => 'string', 'format' => 'uri' }
              },
              'required' => ['@type', 'dc:entityUrl']
            }
          end

          # Collection reference per attributes/_collection.jb.
          def collection_reference
            {
              'type' => 'object',
              'title' => 'CollectionReference',
              'properties' => {
                '@id' => id_property,
                '@type' => type_names_property('schemas.collection_reference_type'),
                'name' => { 'type' => 'string' },
                'url' => { 'type' => 'string', 'format' => 'uri' },
                'dc:slug' => { 'type' => 'string' }
              },
              'required' => ['@id', '@type']
            }
          end
        end
      end
    end
  end
end
