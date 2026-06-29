# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module MasterData
    module Templates
      # Coverage for AggregateTemplate's transform helpers: the array-of-arrays
      # schema_ancestors header, override-feature merge, inverse-property cleanup,
      # slug/nested-property definitions and the empty additional-base-templates
      # fallback. Pure in-memory hash transforms, driven via the private methods.
      class AggregateTemplateCoverageTest < DataCycleCore::TestCases::ActiveSupportTestCase
        def build(data)
          DataCycleCore::MasterData::Templates::AggregateTemplate.new(data:)
        end

        test 'transform_aggregate_header! appends the schema type to each ancestor list' do
          at = build({ name: 'POI', schema_ancestors: [['schema.org', 'Thing']] })

          at.send(:transform_aggregate_header!)
          aggregate = at.instance_variable_get(:@aggregate)

          assert_equal('POI (Aggregate)', aggregate[:name])
          assert_includes(aggregate[:schema_ancestors].first, 'dcls:POI')
        end

        test 'transform_override_properties! merges aggregate override features' do
          at = build({ features: { aggregate: { features: { custom_feature: { allowed: true } } } } })

          at.send(:transform_override_properties!)

          assert(at.instance_variable_get(:@aggregate).dig('features', 'custom_feature', 'allowed'))
        end

        test 'transform_inverse_properties! strips inverse linking keys' do
          at = build({ properties: { 'linked_prop' => { type: 'linked', link_direction: 'inverse', inverse_of: 'x' } } })

          at.send(:transform_inverse_properties!)
          prop = at.instance_variable_get(:@aggregate)[:properties]['linked_prop']

          assert_not(prop.key?('inverse_of'))
          assert_not(prop.key?('link_direction'))
        end

        test 'slug_definition builds a slug compute definition' do
          result = build({ name: 'X' }).send(:slug_definition, key: 'slug', prop: { 'type' => 'string' })

          assert_equal('slug', result.first.first)
          assert_equal('Slug', result.first.last.dig('compute', 'module'))
        end

        test 'transform_nested_properties! marks nested properties as readonly' do
          prop = { 'properties' => { 'nested' => { 'type' => 'string' } } }.with_indifferent_access

          build({ name: 'X' }).send(:transform_nested_properties!, prop:)

          assert(prop.dig('properties', 'nested', 'ui', 'edit', 'readonly'))
        end

        test 'additional_base_template_names is empty without additional templates' do
          assert_equal([], build({ name: 'X' }).send(:additional_base_template_names))
        end
      end
    end
  end
end
