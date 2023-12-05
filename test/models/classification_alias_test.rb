# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'
require 'minitest/autorun'
require 'helpers/minitest_spec_helper'

describe DataCycleCore::ClassificationAlias do
  include DataCycleCore::MinitestSpecHelper

  def classification_tree
    @classification_tree ||= DataCycleCore::ClassificationTreeLabel.create!(name: 'CLASSIFICATION TREE')
  end

  after do
    classification_tree.tap(&:reload).classification_aliases.map(&:classifications).each(&:delete_all!)
    classification_tree.tap(&:reload).classification_aliases.map(&:classification_groups).each(&:delete_all!)
    classification_tree.tap(&:reload).classification_aliases.delete_all!
    classification_tree.tap(&:reload).classification_trees.delete_all!
    classification_tree.tap(&:reload).destroy_fully!
    @classification_tree = nil
  end

  it 'should pass on updated name to primary classification' do
    classification_alias = classification_tree.create_classification_alias('CLASSIFICATION I', 'CLASSIFICATION I - A')

    classification_alias.name = 'UPDATED NAME'
    classification_alias.save!

    assert(classification_alias.name, 'UPDATED NAME')
    assert(classification_alias.primary_classification.name, 'UPDATED NAME')
  end

  describe 'when creating external classifications from table' do
    def external_system
      @external_system ||= DataCycleCore::ExternalSystem.create!(name: 'SOME EXTERNAL SYSTEM', identifier: 'some_external_system')
    end

    def classification_tree
      @classification_tree ||= DataCycleCore::ClassificationTreeLabel.create!(
        name: 'EXTERNAL CLASSIFICATION TREE',
        external_source: external_system
      )
    end

    def another_classification_tree
      @another_classification_tree ||= DataCycleCore::ClassificationTreeLabel.create!(
        name: 'ANOTHER EXTERNAL CLASSIFICATION TREE',
        external_source: external_system
      )
    end

    after do
      classification_tree.tap(&:reload).classification_aliases.map(&:classifications).each(&:delete_all!)
      classification_tree.tap(&:reload).classification_aliases.map(&:classification_groups).each(&:delete_all!)
      classification_tree.tap(&:reload).classification_aliases.delete_all!
      classification_tree.tap(&:reload).classification_trees.delete_all!
      classification_tree.tap(&:reload).destroy_fully!
      @classification_tree = nil

      another_classification_tree.tap(&:reload).classification_aliases.map(&:classifications).each(&:delete_all!)
      another_classification_tree.tap(&:reload).classification_aliases.map(&:classification_groups).each(&:delete_all!)
      another_classification_tree.tap(&:reload).classification_aliases.delete_all!
      another_classification_tree.tap(&:reload).classification_trees.delete_all!
      another_classification_tree.tap(&:reload).destroy_fully!
      @another_classification_tree = nil

      external_system.destroy!
      @external_system = nil
    end

    it 'should create top level classifications' do
      classification_tree.upsert_all_external_classifications(
        [
          {external_key: 'key:alpha', parent_external_key: nil, name: 'Alpha'},
          {external_key: 'key:beta', parent_external_key: nil, name: 'Beta'}
        ]
      )

      classification_alias_a = DataCycleCore::ClassificationAlias.for_tree('EXTERNAL CLASSIFICATION TREE').with_name('Alpha').first
      refute_nil(classification_alias_a) # rubocop:disable Rails/RefuteMethods
      assert_equal('Alpha', classification_alias_a.name)
      assert_equal('Alpha', classification_alias_a.internal_name)
      assert_equal('key:alpha', classification_alias_a.external_key)

      classification_alias_a = DataCycleCore::ClassificationAlias.for_tree('EXTERNAL CLASSIFICATION TREE').with_name('Beta').first
      refute_nil(classification_alias_a) # rubocop:disable Rails/RefuteMethods
      assert_equal('Beta', classification_alias_a.name)
      assert_equal('Beta', classification_alias_a.internal_name)
      assert_equal('key:beta', classification_alias_a.external_key)
    end

    it 'should create nested classifications' do
      classification_tree.upsert_all_external_classifications(
        [
          {external_key: 'key:alpha', parent_external_key: nil, name: 'Alpha'},
          {external_key: 'key:alpha_1', parent_external_key: 'key:alpha', name: 'Alpha - 1'},
          {external_key: 'key:alpha_1_a', parent_external_key: 'key:alpha_1', name: 'Alpha - 1 - a'},
          {external_key: 'key:beta', parent_external_key: nil, name: 'Beta'},
          {external_key: 'key:beta_1', parent_external_key: 'key:beta', name: 'Beta - 1'}
        ]
      )

      paths = DataCycleCore::ClassificationAlias.for_tree('EXTERNAL CLASSIFICATION TREE').with_name('Alpha').with_descendants.map(&:full_path)
      assert(paths.include?('EXTERNAL CLASSIFICATION TREE > Alpha'))
      assert(paths.include?('EXTERNAL CLASSIFICATION TREE > Alpha > Alpha - 1'))
      assert(paths.include?('EXTERNAL CLASSIFICATION TREE > Alpha > Alpha - 1 > Alpha - 1 - a'))

      paths = DataCycleCore::ClassificationAlias.for_tree('EXTERNAL CLASSIFICATION TREE').with_name('Beta').with_descendants.map(&:full_path)
      assert(paths.include?('EXTERNAL CLASSIFICATION TREE > Beta'))
      assert(paths.include?('EXTERNAL CLASSIFICATION TREE > Beta > Beta - 1'))
    end

    it 'should update existing classifications' do
      classification_tree.upsert_all_external_classifications(
        [
          {external_key: 'key:alpha', parent_external_key: nil, name: 'Alpha'},
          {external_key: 'key:alpha_1', parent_external_key: 'key:alpha', name: 'Alpha - 1'},
          {external_key: 'key:alpha_1_a', parent_external_key: 'key:alpha_1', name: 'Alpha - 1 - a'}
        ]
      )

      classification_tree.upsert_all_external_classifications(
        [
          {external_key: 'key:alpha', parent_external_key: nil, name: 'Alpha'},
          {external_key: 'key:alpha_1', parent_external_key: 'key:alpha', name: 'UPDATED - Alpha - 1'},
          {external_key: 'key:alpha_1_a', parent_external_key: 'key:alpha_1', name: 'Alpha - 1 - a'}
        ]
      )

      classification_alias = DataCycleCore::ClassificationAlias.for_tree('EXTERNAL CLASSIFICATION TREE').with_name('UPDATED - Alpha - 1').first
      refute_nil(classification_alias) # rubocop:disable Rails/RefuteMethods
      assert_equal('UPDATED - Alpha - 1', classification_alias.name)
      assert_equal('UPDATED - Alpha - 1', classification_alias.internal_name)
      assert_equal('key:alpha_1', classification_alias.external_key)

      paths = DataCycleCore::ClassificationAlias.for_tree('EXTERNAL CLASSIFICATION TREE').with_name('Alpha').with_descendants.map(&:full_path)

      assert(paths.include?('EXTERNAL CLASSIFICATION TREE > Alpha'))
      assert(paths.include?('EXTERNAL CLASSIFICATION TREE > Alpha > UPDATED - Alpha - 1'))
      assert(paths.include?('EXTERNAL CLASSIFICATION TREE > Alpha > UPDATED - Alpha - 1 > Alpha - 1 - a'))
    end

    it 'should update classification hierarchies' do
      classification_tree.upsert_all_external_classifications(
        [
          {external_key: 'key:alpha', parent_external_key: nil, name: 'Alpha'},
          {external_key: 'key:alpha_1', parent_external_key: 'key:alpha', name: 'Alpha - 1'},
          {external_key: 'key:alpha_1_a', parent_external_key: 'key:alpha_1', name: 'Alpha - 1 - a'},
          {external_key: 'key:beta', parent_external_key: nil, name: 'Beta'}
        ]
      )

      classification_tree.upsert_all_external_classifications(
        [
          {external_key: 'key:alpha', parent_external_key: nil, name: 'Alpha'},
          {external_key: 'key:beta', parent_external_key: nil, name: 'Beta'},
          {external_key: 'key:alpha_1', parent_external_key: 'key:beta', name: 'Alpha - 1'},
          {external_key: 'key:alpha_1_a', parent_external_key: 'key:alpha_1', name: 'Alpha - 1 - a'}
        ]
      )

      paths = DataCycleCore::ClassificationAlias.for_tree('EXTERNAL CLASSIFICATION TREE').with_name('Alpha').with_descendants.map(&:full_path)
      assert_equal(1, paths.size)

      paths = DataCycleCore::ClassificationAlias.for_tree('EXTERNAL CLASSIFICATION TREE').with_name('Beta').with_descendants.map(&:full_path)
      assert(paths.include?('EXTERNAL CLASSIFICATION TREE > Beta'))
      assert(paths.include?('EXTERNAL CLASSIFICATION TREE > Beta > Alpha - 1'))
      assert(paths.include?('EXTERNAL CLASSIFICATION TREE > Beta > Alpha - 1 > Alpha - 1 - a'))
    end

    it 'should update internal name only for primary language' do
      classification_tree.upsert_all_external_classifications(
        [
          {external_key: 'key:alpha', parent_external_key: nil, name: 'Alpha'},
          {external_key: 'key:alpha_1', parent_external_key: 'key:alpha', name: 'Alpha - 1'},
          {external_key: 'key:alpha_1_a', parent_external_key: 'key:alpha_1', name: 'Alpha - 1 - a'}
        ]
      )

      I18n.with_locale(:en) do
        classification_tree.upsert_all_external_classifications(
          [
            {external_key: 'key:alpha', parent_external_key: nil, name: 'EN: Alpha'},
            {external_key: 'key:alpha_1', parent_external_key: 'key:alpha', name: 'EN: Alpha - 1'},
            {external_key: 'key:alpha_1_a', parent_external_key: 'key:alpha_1', name: 'EN: Alpha - 1 - a'}
          ]
        )
      end

      paths = DataCycleCore::ClassificationAlias.for_tree('EXTERNAL CLASSIFICATION TREE').with_name('Alpha').with_descendants.map(&:full_path)
      assert(paths.include?('EXTERNAL CLASSIFICATION TREE > Alpha'))
      assert(paths.include?('EXTERNAL CLASSIFICATION TREE > Alpha > Alpha - 1'))
      assert(paths.include?('EXTERNAL CLASSIFICATION TREE > Alpha > Alpha - 1 > Alpha - 1 - a'))
    end

    it 'should update classification tree (labels)' do
      classification_tree.upsert_all_external_classifications(
        [
          {external_key: 'key:alpha', parent_external_key: nil, name: 'Alpha'},
          {external_key: 'key:alpha_1', parent_external_key: 'key:alpha', name: 'Alpha - 1'},
          {external_key: 'key:alpha_1_a', parent_external_key: 'key:alpha_1', name: 'Alpha - 1 - a'}
        ]
      )

      another_classification_tree.upsert_all_external_classifications(
        [
          {external_key: 'key:alpha', parent_external_key: nil, name: 'Alpha'},
          {external_key: 'key:alpha_1', parent_external_key: 'key:alpha', name: 'Alpha - 1'},
          {external_key: 'key:alpha_1_a', parent_external_key: 'key:alpha_1', name: 'Alpha - 1 - a'}
        ]
      )

      paths = DataCycleCore::ClassificationAlias.for_tree('ANOTHER EXTERNAL CLASSIFICATION TREE').with_name('Alpha').with_descendants.map(&:full_path)
      assert(paths.include?('ANOTHER EXTERNAL CLASSIFICATION TREE > Alpha'))
      assert(paths.include?('ANOTHER EXTERNAL CLASSIFICATION TREE > Alpha > Alpha - 1'))
      assert(paths.include?('ANOTHER EXTERNAL CLASSIFICATION TREE > Alpha > Alpha - 1 > Alpha - 1 - a'))
    end
  end

  describe 'when searching' do
    before do
      classification_tree.create_classification_alias('A')
      classification_tree.create_classification_alias('A', 'A - 1')
      classification_tree.create_classification_alias('A', 'AB - 2')
      classification_tree.create_classification_alias('B')
      classification_tree.create_classification_alias('B', 'BCD - 1')
      classification_tree.create_classification_alias('X')
      classification_tree.create_classification_alias('X', '9')
      classification_tree.create_classification_alias('X', '8')
      classification_tree.create_classification_alias('X', '7')
    end

    it 'should return matching classification aliases' do
      assert(DataCycleCore::ClassificationAlias.for_tree('CLASSIFICATION TREE').search('B').count, 3)
      assert(DataCycleCore::ClassificationAlias.for_tree('CLASSIFICATION TREE').search('b').count, 3)
      assert(DataCycleCore::ClassificationAlias.for_tree('CLASSIFICATION TREE').search('1').count, 2)
      assert(DataCycleCore::ClassificationAlias.for_tree('CLASSIFICATION TREE').search('2').count, 1)
    end

    it 'should include descendants' do
      paths = DataCycleCore::ClassificationAlias.for_tree('CLASSIFICATION TREE').search('X').map(&:full_path)

      assert(paths.size, 4)
      assert(paths.include?('CLASSIFICATION TREE > X'))
      assert(paths.include?('CLASSIFICATION TREE > X > 7'))
      assert(paths.include?('CLASSIFICATION TREE > X > 8'))
      assert(paths.include?('CLASSIFICATION TREE > X > 9'))
    end
  end

  describe 'when including descendants' do
    before do
      classification_tree.create_classification_alias('A')
      classification_tree.create_classification_alias('A', 'A - 1')
      classification_tree.create_classification_alias('A', 'A - 2')
      classification_tree.create_classification_alias('A', 'A - 3')
      classification_tree.create_classification_alias('A', 'A - 3', 'A - 3 - a')
      classification_tree.create_classification_alias('A', 'A - 3', 'A - 3 - b')
      classification_tree.create_classification_alias('A', 'A - 3', 'A - 3 - c')
    end

    it 'should return correct number of classification aliases' do
      assert(DataCycleCore::ClassificationAlias.for_tree('CLASSIFICATION TREE').with_name('A - 3').with_descendants.count, 4)
    end

    it 'should return classification aliases with correct name' do
      names = DataCycleCore::ClassificationAlias.for_tree('CLASSIFICATION TREE')
        .with_name('A - 3')
        .with_descendants
        .map(&:name)

      assert(names.include?('A - 3'))
      assert(names.include?('A - 3 - a'))
      assert(names.include?('A - 3 - b'))
      assert(names.include?('A - 3 - c'))
    end

    it 'should return classification aliases with correct paths' do
      paths = DataCycleCore::ClassificationAlias.for_tree('CLASSIFICATION TREE')
        .with_name('A - 3')
        .with_descendants
        .map(&:full_path)

      assert(paths.include?('CLASSIFICATION TREE > A > A - 3'))
      assert(paths.include?('CLASSIFICATION TREE > A > A - 3 > A - 3 - a'))
      assert(paths.include?('CLASSIFICATION TREE > A > A - 3 > A - 3 - b'))
      assert(paths.include?('CLASSIFICATION TREE > A > A - 3 > A - 3 - c'))
    end
  end

  describe 'when loading descendants' do
    before do
      classification_tree.create_classification_alias('A')
      classification_tree.create_classification_alias('A', 'A - 1')
      classification_tree.create_classification_alias('A', 'A - 2')
      classification_tree.create_classification_alias('A', 'A - 3')
      classification_tree.create_classification_alias('A', 'A - 3', 'A - 3 - a')
      classification_tree.create_classification_alias('A', 'A - 3', 'A - 3 - b')
      classification_tree.create_classification_alias('A', 'A - 3', 'A - 3 - c')
    end

    it 'should return correct number of descendants' do
      assert(DataCycleCore::ClassificationAlias.for_tree('CLASSIFICATION TREE').with_name('A').first.descendants.count, 6)
      assert(DataCycleCore::ClassificationAlias.for_tree('CLASSIFICATION TREE').with_name('A - 3').first.descendants.count, 3)
    end

    it 'should return descendants with correct name' do
      names = DataCycleCore::ClassificationAlias.for_tree('CLASSIFICATION TREE').with_name('A - 3')
        .first.descendants.map(&:name)

      assert(names.exclude?('A'))
      assert(names.exclude?('A - 1'))
      assert(names.exclude?('A - 2'))
      assert(names.exclude?('A - 3'))
      assert(names.include?('A - 3 - a'))
      assert(names.include?('A - 3 - b'))
      assert(names.include?('A - 3 - c'))
    end
  end

  describe 'when sorting by similarity' do
    before do
      classification_tree.create_classification_alias('A')
      classification_tree.create_classification_alias('A', 'Frühling')
      classification_tree.create_classification_alias('A', 'Sommer')
      classification_tree.create_classification_alias('A', 'Sommer', 'Montag')
      classification_tree.create_classification_alias('A', 'Sommer', 'Dienstag')
      classification_tree.create_classification_alias('A', 'Sommer', 'Mittwoch')
      classification_tree.create_classification_alias('A', 'Sommer', 'Donnerstag')
      classification_tree.create_classification_alias('A', 'Sommer', 'Freitag')
      classification_tree.create_classification_alias('A', 'Sommer', 'Samstag')
      classification_tree.create_classification_alias('A', 'Sommer', 'Sonntag')
    end

    it 'should order correctly' do
      paths = DataCycleCore::ClassificationAlias.for_tree('CLASSIFICATION TREE').with_name('Sommer')
        .with_descendants.order_by_similarity('Sommer').map(&:full_path)

      assert(paths[0], 'CLASSIFICATION TREE > A > Sommer')
      assert(paths[1], 'CLASSIFICATION TREE > A > Sommer > Sonntag')
      assert(paths[2], 'CLASSIFICATION TREE > A > Sommer > Samstag')
    end
  end
end
