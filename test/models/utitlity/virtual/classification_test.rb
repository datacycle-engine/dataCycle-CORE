# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Utility
    module Virtual
      class ClassificationTest < DataCycleCore::TestCases::ActiveSupportTestCase
        def subject
          DataCycleCore::Utility::Virtual::Classification
        end

        test 'concat joins the configured key of each parameter classification' do
          classifications = Struct.new(:classification_aliases) {
            def loaded? = false
          }.new([struct_double(name: 'Alpha', internal_name: 'alpha'), struct_double(name: 'Beta', internal_name: 'beta')])
          content = struct_double(cats: classifications)

          value = subject.concat(virtual_parameters: ['cats'], content:, virtual_definition: { virtual: { key: 'name' } })

          assert_equal('Alpha, Beta', value)
        end

        test 'concat returns nil when there are no classification values' do
          classifications = Struct.new(:classification_aliases) {
            def loaded? = false
          }.new([])
          content = struct_double(cats: classifications)

          assert_nil(subject.concat(virtual_parameters: ['cats'], content:, virtual_definition: { virtual: { key: 'name' } }))
        end

        test 'by_tree_label returns the primary classifications for the configured tree' do
          content = struct_double(full_classification_aliases: classification_relation_double)

          assert_equal(['primary-1'], subject.by_tree_label(content:, virtual_definition: { 'tree_label' => 'Lizenzen' }))
        end

        test 'by_tree_label returns nil without a tree label' do
          assert_nil(subject.by_tree_label(content: struct_double(full_classification_aliases: classification_relation_double), virtual_definition: {}))
        end

        test 'value_by_concept_scheme picks the configured key for the concept scheme' do
          content = struct_double(full_classification_aliases: classification_relation_double)

          value = subject.value_by_concept_scheme(content:, virtual_definition: { 'virtual' => { 'concept_scheme' => 'Lizenzen', 'key' => 'uri' } })

          assert_equal('license-uri', value)
        end

        test 'value_by_concept_scheme returns nil without a concept scheme' do
          assert_nil(subject.value_by_concept_scheme(content: struct_double(full_classification_aliases: classification_relation_double), virtual_definition: { 'virtual' => {} }))
        end

        test 'values_by_concept_scheme joins all values for the concept scheme' do
          content = struct_double(full_classification_aliases: classification_relation_double)

          value = subject.values_by_concept_scheme(content:, virtual_definition: { 'virtual' => { 'concept_scheme' => 'Lizenzen' } })

          assert_equal('Tag A, Tag B', value)
        end

        test 'to_mapped_value maps classification names through the configured mapping' do
          content = struct_double(tags: Class.new { def pluck(_key) = ['A'] }.new)
          definition = { 'virtual' => { 'mapping' => { 'A' => 'mapped-a' } } }

          assert_equal(['mapped-a'], subject.to_mapped_value(virtual_parameters: ['tags'], content:, virtual_definition: definition))
        end

        test 'to_mapped_value returns the first value for boolean types' do
          content = struct_double(tags: Class.new { def pluck(_key) = ['A'] }.new)
          definition = { 'type' => 'boolean', 'virtual' => { 'mapping' => { 'A' => 'mapped-a' } } }

          assert_equal('mapped-a', subject.to_mapped_value(virtual_parameters: ['tags'], content:, virtual_definition: definition))
        end

        private

        def classification_relation_double
          Class.new {
            def for_tree(_tree) = self
            def pick(_key) = 'license-uri'
            def pluck(_key) = ['Tag A', 'Tag B']
            def primary_classifications = ['primary-1']
          }.new
        end
      end
    end
  end
end
