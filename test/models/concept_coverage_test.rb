# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  # Coverage for Concept methods not exercised by the spec-based
  # classification_alias_test.rb: class scopes, serializers, status helpers and
  # the move_to_path / merge tree operations.
  class ConceptCoverageTest < DataCycleCore::TestCases::ActiveSupportTestCase
    def build_tree(name = "COV TREE #{SecureRandom.hex(4)}")
      DataCycleCore::ConceptScheme.create!(name:)
    end

    def alias_named(label, name)
      DataCycleCore::Concept.for_tree(label.name).with_name(name).first
    end

    test 'Path is readonly' do
      label = build_tree
      concept = label.create_concept('Root')

      assert_predicate concept.concept_path, :readonly?
    end

    test 'class-level concept_polygons scopes by the relation' do
      label = build_tree
      label.create_concept('Root')
      relation = DataCycleCore::Concept.for_tree(label.name)

      assert_kind_of(ActiveRecord::Relation, relation.concept_polygons)
    end

    test 'find_content_template matches by name and walks up ancestors' do
      label = build_tree
      leaf = label.create_concept('Parent', 'Child')
      parent = alias_named(label, 'Parent')

      child_match = struct_double(schema: { 'properties' => { 'data_type' => { 'default_value' => 'Child' } } })
      parent_match = struct_double(schema: { 'properties' => { 'data_type' => { 'default_value' => 'Parent' } } })
      none = struct_double(schema: {})

      assert_equal(child_match, leaf.find_content_template([child_match]))
      assert_equal(parent_match, leaf.find_content_template([parent_match]))
      assert_nil(parent.find_content_template([none]))
    end

    test 'external_keys and mapped_inverse_concepts read the mappings' do
      label = build_tree
      concept = label.create_concept('Root')

      assert_kind_of(String, concept.external_keys)
      assert_empty(concept.mapped_inverse_concepts)
    end

    test 'to_hash exposes class_type and the external system' do
      label = build_tree
      concept = label.create_concept('Root')
      hash = concept.to_hash

      assert_equal('DataCycleCore::Concept', hash['class_type'])
      assert(hash.key?('external_system'))
      assert_equal(concept.id, hash['id'])
    end

    test 'icon returns nil without a configured icon and the asset url with one' do
      label = build_tree
      concept = label.create_concept('Root')

      assert_nil concept.icon

      view_helpers = Class.new { def dc_image_url(path) = "/assets/#{path}" }.new

      DataCycleCore.stub(:classification_icons, { concept.id => 'flag.svg' }) do
        DataCycleCore::LocalizationService.stub(:view_helpers, view_helpers) do
          assert_equal('/assets/icons/flag.svg', concept.icon)
        end
      end
    end

    test 'validate_color_format rejects non-hex colors' do
      label = build_tree
      concept = label.create_concept('Root')
      concept.ui_configs = { 'color' => 'not-a-hex' }
      concept.valid?

      assert concept.errors.added?(:ui_configs, :color_format)
    end

    test 'merge_with_children with destroy_children merges descendants into self then the target' do
      label = build_tree
      label.create_concept('Source', 'Source Child')
      label.create_concept('Target')
      source = alias_named(label, 'Source')
      target = alias_named(label, 'Target')

      assert_nothing_raised { source.merge_with_children(target, destroy_children: true) }
    end

    test 'move_to_path merges into an existing target referenced by id' do
      label = build_tree
      label.create_concept('Mover')
      label.create_concept('Destination')
      mover = alias_named(label, 'Mover')
      destination = alias_named(label, 'Destination')

      assert_not_nil mover.move_to_path([destination.id])
    end

    test 'move_to_path moves an alias by name path when the target does not exist' do
      label = build_tree
      label.create_concept('Mover')
      mover = alias_named(label, 'Mover')

      assert_not_nil mover.move_to_path([label.name, 'New Section'])
    end

    test 'move_to_path returns early for a blank path' do
      label = build_tree
      concept = label.create_concept('Root')

      assert_nil concept.move_to_path(nil)
    end
  end
end
