# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Utility
    module Compute
      class BaseTest < DataCycleCore::TestCases::ActiveSupportTestCase
        def subject
          DataCycleCore::Utility::Compute::Base
        end

        test 'equals? compares two values' do
          assert(subject.equals?('a', 'a'))
          assert_not(subject.equals?('a', 'b'))
        end

        test 'exists? checks for presence' do
          assert(subject.exists?('value', nil))
          assert_not(subject.exists?('', nil))
          assert_not(subject.exists?(nil, nil))
        end

        test 'not_exists? checks for absence' do
          assert(subject.not_exists?('', nil))
          assert(subject.not_exists?(nil, nil))
          assert_not(subject.not_exists?('value', nil))
        end

        # [#51643] the condition Extensions::Generated injects into every _generated companion, so
        # a machine only fills an attribute the editors left empty in this locale
        test 'condition_satisfied? evaluates not_exists? against a content attribute' do
          definition = { 'type' => 'content', 'name' => 'description', 'method' => 'not_exists?' }

          assert(subject.condition_satisfied?(struct_double(description: nil), definition, nil))
          assert_not(subject.condition_satisfied?(struct_double(description: 'Ein Feld voller Lavendel'), definition, nil))
        end

        # Stands in for a Thing while resolving a compute chain: the stored values plus the
        # property definitions, which is all Compute::Base reads.
        class ContentDouble
          def initialize(definitions:, stored:)
            @definitions = definitions
            @stored = stored
          end

          def properties_for(key)
            @definitions[key.to_s]
          end

          def property_names
            @definitions.keys
          end

          def computed_property_names
            @definitions.select { |_, definition| definition.key?('compute') }.keys
          end

          def attribute_to_h(key)
            @stored[key.to_s]
          end

          def try(name, *)
            respond_to?(name) ? public_send(name) : @stored[name.to_s]
          end
        end

        # [#51643] 'contributor_generated' lists the companion attribute among its parameters, and
        # the companion declines to compute while the editorial attribute has a value - the marking
        # still has to be computed, from the value the companion has stored.
        test 'a compute depending on a conditionally skipped compute sees its stored value' do
          definitions = {
            'description' => {},
            'description_generated' => {
              'compute' => {
                'module' => 'Common',
                'method' => 'copy',
                'parameters' => ['name'],
                'condition' => [{ 'type' => 'content', 'name' => 'description', 'method' => 'not_exists?' }]
              }
            },
            'marker' => { 'compute' => { 'module' => 'Common', 'method' => 'take_first', 'parameters' => ['description_generated'] } }
          }
          content = ContentDouble.new(definitions:, stored: { 'name' => 'Titel', 'description' => 'Redaktionell', 'description_generated' => 'Generiert' })
          data_hash = {}

          subject.compute_values('marker', data_hash, content, nil, true)

          assert_equal('Generiert', data_hash['marker'])
        end

        # The stored value stands in for a compute its :condition: declined, and only for that one:
        # a compute #skip_compute_value? declined could not resolve its own parameters, so running
        # the depending compute against whatever it stored earlier would be a guess.
        test 'condition_blocked? holds for a compute its condition declined alone' do
          definitions = {
            'description' => {},
            'description_generated' => {
              'compute' => {
                'module' => 'Common',
                'method' => 'copy',
                'parameters' => ['name'],
                'condition' => [{ 'type' => 'content', 'name' => 'description', 'method' => 'not_exists?' }]
              }
            }
          }
          blocked = ContentDouble.new(definitions:, stored: { 'description' => 'Redaktionell' })
          free = ContentDouble.new(definitions:, stored: { 'description' => nil })

          assert(subject.condition_blocked?(blocked, 'description_generated', nil))
          assert_not(subject.condition_blocked?(free, 'description_generated', nil))
          assert_not(subject.condition_blocked?(blocked, 'description', nil))
        end

        test 'condition_satisfied? reads from the external source default options' do
          content = struct_double(external_source: struct_double(default_options: { 'channel' => 'feratel' }))
          definition = { 'type' => 'external_source', 'name' => 'channel', 'method' => 'equals?', 'value' => 'feratel' }

          assert(subject.condition_satisfied?(content, definition, nil))
        end

        test 'condition_satisfied? reads an I18n value' do
          definition = { 'type' => 'I18n', 'name' => 'locale', 'method' => 'exists?' }

          assert(subject.condition_satisfied?(nil, definition, nil))
        end

        test 'condition_satisfied? evaluates an allowed current_user method' do
          definition = { 'type' => 'current_user', 'name' => 'present?', 'method' => 'equals?', 'value' => true }

          assert(subject.condition_satisfied?(nil, definition, struct_double(id: 1)))
        end

        test 'condition_satisfied? raises for an unknown current_user method' do
          definition = { 'type' => 'current_user', 'name' => 'destroy', 'method' => 'equals?', 'value' => true }

          error = assert_raises(RuntimeError) { subject.condition_satisfied?(nil, definition, struct_double(id: 1)) }
          assert_equal('unknown method for current_user', error.message)
        end

        test 'condition_satisfied? raises for an unknown type' do
          definition = { 'type' => 'bogus', 'name' => 'x', 'method' => 'equals?' }

          error = assert_raises(RuntimeError) { subject.condition_satisfied?(nil, definition, nil) }
          assert_equal('Unknown type for validation', error.message)
        end
      end
    end
  end
end
