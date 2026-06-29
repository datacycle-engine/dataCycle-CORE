# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  # Coverage for ClassificationAlias methods not exercised by the spec-based
  # classification_alias_test.rb: class scopes, serializers, status helpers and
  # the move_to_path / merge tree operations.
  class ClassificationAliasCoverageTest < DataCycleCore::TestCases::ActiveSupportTestCase
    def build_tree(name = "COV TREE #{SecureRandom.hex(4)}")
      DataCycleCore::ClassificationTreeLabel.create!(name:)
    end

    def alias_named(label, name)
      DataCycleCore::ClassificationAlias.for_tree(label.name).with_name(name).first
    end

    test 'Path is readonly' do
      label = build_tree
      ca = label.create_classification_alias('Root')

      assert_predicate ca.classification_alias_path, :readonly?
    end

    test 'class-level classifications and classification_polygons scope by the relation' do
      label = build_tree
      label.create_classification_alias('Root')
      relation = DataCycleCore::ClassificationAlias.for_tree(label.name)

      assert_kind_of(ActiveRecord::Relation, relation.classifications)
      assert_kind_of(ActiveRecord::Relation, relation.classification_polygons)
    end

    test 'find_content_template matches by name and walks up ancestors' do
      label = build_tree
      leaf = label.create_classification_alias('Parent', 'Child')
      parent = alias_named(label, 'Parent')

      child_match = struct_double(schema: { 'properties' => { 'data_type' => { 'default_value' => 'Child' } } })
      parent_match = struct_double(schema: { 'properties' => { 'data_type' => { 'default_value' => 'Parent' } } })
      none = struct_double(schema: {})

      assert_equal(child_match, leaf.find_content_template([child_match]))
      assert_equal(parent_match, leaf.find_content_template([parent_match]))
      assert_nil(parent.find_content_template([none]))
    end

    test 'external_keys, mapped_to and mapped_to_string read the classification mappings' do
      label = build_tree
      ca = label.create_classification_alias('Root')

      assert_kind_of(String, ca.external_keys)
      assert_equal('', ca.mapped_to_string)
      assert_empty(ca.mapped_to)
    end

    test 'to_hash exposes class_type and primary_classification' do
      label = build_tree
      ca = label.create_classification_alias('Root')
      hash = ca.to_hash

      assert_equal('DataCycleCore::ClassificationAlias', hash['class_type'])
      assert(hash.key?('primary_classification'))
    end

    test 'icon returns nil without a configured icon and the asset url with one' do
      label = build_tree
      ca = label.create_classification_alias('Root')

      assert_nil ca.icon

      view_helpers = Class.new { def dc_image_url(path) = "/assets/#{path}" }.new

      DataCycleCore.stub(:classification_icons, { ca.id => 'flag.svg' }) do
        DataCycleCore::LocalizationService.stub(:view_helpers, view_helpers) do
          assert_equal('/assets/icons/flag.svg', ca.icon)
        end
      end
    end

    test 'validate_color_format rejects non-hex colors' do
      label = build_tree
      ca = label.create_classification_alias('Root')
      ca.ui_configs = { 'color' => 'not-a-hex' }
      ca.valid?

      assert ca.errors.added?(:ui_configs, :color_format)
    end

    test 'merge_with_children with destroy_children merges descendants into self then the target' do
      label = build_tree
      label.create_classification_alias('Source', 'Source Child')
      label.create_classification_alias('Target')
      source = alias_named(label, 'Source')
      target = alias_named(label, 'Target')

      assert_nothing_raised { source.merge_with_children(target, true) }
    end

    test 'move_to_path merges into an existing target referenced by id' do
      label = build_tree
      label.create_classification_alias('Mover')
      label.create_classification_alias('Destination')
      mover = alias_named(label, 'Mover')
      destination = alias_named(label, 'Destination')

      assert_not_nil mover.move_to_path([destination.id])
    end

    test 'move_to_path moves an alias by name path when the target does not exist' do
      label = build_tree
      label.create_classification_alias('Mover')
      mover = alias_named(label, 'Mover')

      assert_not_nil mover.move_to_path([label.name, 'New Section'])
    end

    test 'move_to_path returns early for a blank path' do
      label = build_tree
      ca = label.create_classification_alias('Root')

      assert_nil ca.move_to_path(nil)
    end
  end
end
