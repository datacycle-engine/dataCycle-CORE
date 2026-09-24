# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'
require 'minitest/autorun'
require 'helpers/minitest_spec_helper'

describe DataCycleCore::Concept do
  include DataCycleCore::MinitestSpecHelper

  def concept_scheme
    @concept_scheme ||= DataCycleCore::ConceptScheme.create!(name: 'CLASSIFICATION TREE')
  end

  after do
    concept_scheme.reload.destroy
    @concept_scheme = nil
  end

  describe 'when creating external classifications from table' do
    def external_system
      @external_system ||= DataCycleCore::ExternalSystem.create!(name: 'SOME EXTERNAL SYSTEM', identifier: 'some_external_system')
    end

    def concept_scheme
      @concept_scheme ||= DataCycleCore::ConceptScheme.create!(
        name: 'EXTERNAL CLASSIFICATION TREE',
        external_system:
      )
    end

    def another_concept_scheme
      @another_concept_scheme ||= DataCycleCore::ConceptScheme.create!(
        name: 'ANOTHER EXTERNAL CLASSIFICATION TREE',
        external_system:
      )
    end

    after do
      concept_scheme.reload.destroy
      @concept_scheme = nil

      another_concept_scheme.reload.destroy
      @another_concept_scheme = nil

      external_system.destroy!
      @external_system = nil
    end

    it 'should create top level classifications' do
      concept_scheme.upsert_all_external_concepts(
        [
          { external_key: 'key:alpha', parent_external_key: nil, name: 'Alpha' },
          { external_key: 'key:beta', parent_external_key: nil, name: 'Beta' }
        ]
      )

      concept = DataCycleCore::Concept.for_tree('EXTERNAL CLASSIFICATION TREE').with_name('Alpha').first

      refute_nil(concept) # rubocop:disable Rails/RefuteMethods
      assert_equal('Alpha', concept.name)
      assert_equal('Alpha', concept.internal_name)
      assert_equal('key:alpha', concept.external_key)

      concept = DataCycleCore::Concept.for_tree('EXTERNAL CLASSIFICATION TREE').with_name('Beta').first

      refute_nil(concept) # rubocop:disable Rails/RefuteMethods
      assert_equal('Beta', concept.name)
      assert_equal('Beta', concept.internal_name)
      assert_equal('key:beta', concept.external_key)
    end

    it 'should create nested classifications' do
      concept_scheme.upsert_all_external_concepts(
        [
          { external_key: 'key:alpha', parent_external_key: nil, name: 'Alpha' },
          { external_key: 'key:alpha_1', parent_external_key: 'key:alpha', name: 'Alpha - 1' },
          { external_key: 'key:alpha_1_a', parent_external_key: 'key:alpha_1', name: 'Alpha - 1 - a' },
          { external_key: 'key:beta', parent_external_key: nil, name: 'Beta' },
          { external_key: 'key:beta_1', parent_external_key: 'key:beta', name: 'Beta - 1' }
        ]
      )

      paths = DataCycleCore::Concept.for_tree('EXTERNAL CLASSIFICATION TREE').with_name('Alpha').with_descendants.map(&:full_path)

      assert_includes(paths, 'EXTERNAL CLASSIFICATION TREE > Alpha')
      assert_includes(paths, 'EXTERNAL CLASSIFICATION TREE > Alpha > Alpha - 1')
      assert_includes(paths, 'EXTERNAL CLASSIFICATION TREE > Alpha > Alpha - 1 > Alpha - 1 - a')

      paths = DataCycleCore::Concept.for_tree('EXTERNAL CLASSIFICATION TREE').with_name('Beta').with_descendants.map(&:full_path)

      assert_includes(paths, 'EXTERNAL CLASSIFICATION TREE > Beta')
      assert_includes(paths, 'EXTERNAL CLASSIFICATION TREE > Beta > Beta - 1')
    end

    it 'should update existing classifications' do
      concept_scheme.upsert_all_external_concepts(
        [
          { external_key: 'key:alpha', parent_external_key: nil, name: 'Alpha' },
          { external_key: 'key:alpha_1', parent_external_key: 'key:alpha', name: 'Alpha - 1' },
          { external_key: 'key:alpha_1_a', parent_external_key: 'key:alpha_1', name: 'Alpha - 1 - a' }
        ]
      )

      concept_scheme.upsert_all_external_concepts(
        [
          { external_key: 'key:alpha', parent_external_key: nil, name: 'Alpha' },
          { external_key: 'key:alpha_1', parent_external_key: 'key:alpha', name: 'UPDATED - Alpha - 1' },
          { external_key: 'key:alpha_1_a', parent_external_key: 'key:alpha_1', name: 'Alpha - 1 - a' }
        ]
      )

      concept = DataCycleCore::Concept.for_tree('EXTERNAL CLASSIFICATION TREE').with_name('UPDATED - Alpha - 1').first

      refute_nil(concept) # rubocop:disable Rails/RefuteMethods
      assert_equal('UPDATED - Alpha - 1', concept.name)
      assert_equal('UPDATED - Alpha - 1', concept.internal_name)
      assert_equal('key:alpha_1', concept.external_key)

      paths = DataCycleCore::Concept.for_tree('EXTERNAL CLASSIFICATION TREE').with_name('Alpha').with_descendants.map(&:full_path)

      assert_includes(paths, 'EXTERNAL CLASSIFICATION TREE > Alpha')
      assert_includes(paths, 'EXTERNAL CLASSIFICATION TREE > Alpha > UPDATED - Alpha - 1')
      assert_includes(paths, 'EXTERNAL CLASSIFICATION TREE > Alpha > UPDATED - Alpha - 1 > Alpha - 1 - a')
    end

    it 'should update classification hierarchies' do
      concept_scheme.upsert_all_external_concepts(
        [
          { external_key: 'key:alpha', parent_external_key: nil, name: 'Alpha' },
          { external_key: 'key:alpha_1', parent_external_key: 'key:alpha', name: 'Alpha - 1' },
          { external_key: 'key:alpha_1_a', parent_external_key: 'key:alpha_1', name: 'Alpha - 1 - a' },
          { external_key: 'key:beta', parent_external_key: nil, name: 'Beta' }
        ]
      )

      concept_scheme.upsert_all_external_concepts(
        [
          { external_key: 'key:alpha', parent_external_key: nil, name: 'Alpha' },
          { external_key: 'key:beta', parent_external_key: nil, name: 'Beta' },
          { external_key: 'key:alpha_1', parent_external_key: 'key:beta', name: 'Alpha - 1' },
          { external_key: 'key:alpha_1_a', parent_external_key: 'key:alpha_1', name: 'Alpha - 1 - a' }
        ]
      )

      paths = DataCycleCore::Concept.for_tree('EXTERNAL CLASSIFICATION TREE').with_name('Alpha').with_descendants.map(&:full_path)

      assert_equal(1, paths.size)

      paths = DataCycleCore::Concept.for_tree('EXTERNAL CLASSIFICATION TREE').with_name('Beta').with_descendants.map(&:full_path)

      assert_includes(paths, 'EXTERNAL CLASSIFICATION TREE > Beta')
      assert_includes(paths, 'EXTERNAL CLASSIFICATION TREE > Beta > Alpha - 1')
      assert_includes(paths, 'EXTERNAL CLASSIFICATION TREE > Beta > Alpha - 1 > Alpha - 1 - a')
    end

    it 'should update internal name only for primary language' do
      concept_scheme.upsert_all_external_concepts(
        [
          { external_key: 'key:alpha', parent_external_key: nil, name: 'Alpha' },
          { external_key: 'key:alpha_1', parent_external_key: 'key:alpha', name: 'Alpha - 1' },
          { external_key: 'key:alpha_1_a', parent_external_key: 'key:alpha_1', name: 'Alpha - 1 - a' }
        ]
      )

      I18n.with_locale(:en) do
        concept_scheme.upsert_all_external_concepts(
          [
            { external_key: 'key:alpha', parent_external_key: nil, name: 'EN: Alpha' },
            { external_key: 'key:alpha_1', parent_external_key: 'key:alpha', name: 'EN: Alpha - 1' },
            { external_key: 'key:alpha_1_a', parent_external_key: 'key:alpha_1', name: 'EN: Alpha - 1 - a' }
          ]
        )
      end

      paths = DataCycleCore::Concept.for_tree('EXTERNAL CLASSIFICATION TREE').with_name('Alpha').with_descendants.map(&:full_path)

      assert_includes(paths, 'EXTERNAL CLASSIFICATION TREE > Alpha')
      assert_includes(paths, 'EXTERNAL CLASSIFICATION TREE > Alpha > Alpha - 1')
      assert_includes(paths, 'EXTERNAL CLASSIFICATION TREE > Alpha > Alpha - 1 > Alpha - 1 - a')
    end

    it 'should update concept schemes' do
      concept_scheme.upsert_all_external_concepts(
        [
          { external_key: 'key:alpha', parent_external_key: nil, name: 'Alpha' },
          { external_key: 'key:alpha_1', parent_external_key: 'key:alpha', name: 'Alpha - 1' },
          { external_key: 'key:alpha_1_a', parent_external_key: 'key:alpha_1', name: 'Alpha - 1 - a' }
        ]
      )

      another_concept_scheme.upsert_all_external_concepts(
        [
          { external_key: 'key:alpha', parent_external_key: nil, name: 'Alpha' },
          { external_key: 'key:alpha_1', parent_external_key: 'key:alpha', name: 'Alpha - 1' },
          { external_key: 'key:alpha_1_a', parent_external_key: 'key:alpha_1', name: 'Alpha - 1 - a' }
        ]
      )

      paths = DataCycleCore::Concept.for_tree('ANOTHER EXTERNAL CLASSIFICATION TREE').with_name('Alpha').with_descendants.map(&:full_path)

      assert_includes(paths, 'ANOTHER EXTERNAL CLASSIFICATION TREE > Alpha')
      assert_includes(paths, 'ANOTHER EXTERNAL CLASSIFICATION TREE > Alpha > Alpha - 1')
      assert_includes(paths, 'ANOTHER EXTERNAL CLASSIFICATION TREE > Alpha > Alpha - 1 > Alpha - 1 - a')
    end
  end

  # Every case above imports into a scheme that has an external system, so all of them are carried
  # by the (external_system_id, external_key) index. A scheme configured in a classifications.yml
  # has none, and the index only covers those rows because it is NULLS NOT DISTINCT: without that,
  # ON CONFLICT matches nothing and each run appends another copy of the whole scheme (#41458).
  describe 'when importing a scheme that has no external system' do
    def payload
      [
        { external_key: 'CLASSIFICATION TREE > Alpha', parent_external_key: nil, name: 'Alpha' },
        { external_key: 'CLASSIFICATION TREE > Alpha > Beta', parent_external_key: 'CLASSIFICATION TREE > Alpha', name: 'Beta' }
      ]
    end

    it 'creates each concept once, however often it is imported' do
      3.times { concept_scheme.insert_all_external_concepts(payload) }

      concepts = DataCycleCore::Concept.where(concept_scheme_id: concept_scheme.id)

      assert_equal(2, concepts.count)
      assert_equal(['CLASSIFICATION TREE > Alpha', 'CLASSIFICATION TREE > Alpha > Beta'], concepts.pluck(:external_key).sort)
    end

    # Counted over the scheme rather than over one looked-up concept: a duplicated Beta still has
    # exactly one broader link of its own, so per-concept assertions hold in the broken state too.
    it 'builds one broader link per concept across repeated imports' do
      2.times { concept_scheme.insert_all_external_concepts(payload) }

      scheme_concepts = DataCycleCore::Concept.where(concept_scheme_id: concept_scheme.id)
      links = DataCycleCore::ConceptLink.where(child_id: scheme_concepts.select(:id), link_type: 'broader')
      beta = scheme_concepts.find_by(external_key: 'CLASSIFICATION TREE > Alpha > Beta')

      assert_equal(2, links.count)
      assert_equal('Alpha', beta.parent.internal_name)
    end
  end

  describe 'when searching' do
    before do
      concept_scheme.create_concept('A')
      concept_scheme.create_concept('A', 'A - 1')
      concept_scheme.create_concept('A', 'AB - 2')
      concept_scheme.create_concept('B')
      concept_scheme.create_concept('B', 'BCD - 1')
      concept_scheme.create_concept('X')
      concept_scheme.create_concept('X', '9')
      concept_scheme.create_concept('X', '8')
      concept_scheme.create_concept('X', '7')
    end

    it 'should return matching concepts' do
      assert_equal(3, DataCycleCore::Concept.for_tree('CLASSIFICATION TREE').search('B').count)
      assert_equal(3, DataCycleCore::Concept.for_tree('CLASSIFICATION TREE').search('b').count)
      assert_equal(2, DataCycleCore::Concept.for_tree('CLASSIFICATION TREE').search('1').count)
      assert_equal(1, DataCycleCore::Concept.for_tree('CLASSIFICATION TREE').search('2').count)
    end

    it 'should include descendants' do
      paths = DataCycleCore::Concept.for_tree('CLASSIFICATION TREE').search('X').map(&:full_path)

      assert_equal(4, paths.size)
      assert_includes(paths, 'CLASSIFICATION TREE > X')
      assert_includes(paths, 'CLASSIFICATION TREE > X > 7')
      assert_includes(paths, 'CLASSIFICATION TREE > X > 8')
      assert_includes(paths, 'CLASSIFICATION TREE > X > 9')
    end
  end

  describe 'when including descendants' do
    before do
      concept_scheme.create_concept('A')
      concept_scheme.create_concept('A', 'A - 1')
      concept_scheme.create_concept('A', 'A - 2')
      concept_scheme.create_concept('A', 'A - 3')
      concept_scheme.create_concept('A', 'A - 3', 'A - 3 - a')
      concept_scheme.create_concept('A', 'A - 3', 'A - 3 - b')
      concept_scheme.create_concept('A', 'A - 3', 'A - 3 - c')
    end

    it 'should return correct number of concepts' do
      assert_equal(4, DataCycleCore::Concept.for_tree('CLASSIFICATION TREE').with_name('A - 3').with_descendants.count)
    end

    it 'should return concepts with correct name' do
      names = DataCycleCore::Concept.for_tree('CLASSIFICATION TREE')
        .with_name('A - 3')
        .with_descendants
        .map(&:name)

      assert_includes(names, 'A - 3')
      assert_includes(names, 'A - 3 - a')
      assert_includes(names, 'A - 3 - b')
      assert_includes(names, 'A - 3 - c')
    end

    it 'should return concepts with correct paths' do
      paths = DataCycleCore::Concept.for_tree('CLASSIFICATION TREE')
        .with_name('A - 3')
        .with_descendants
        .map(&:full_path)

      assert_includes(paths, 'CLASSIFICATION TREE > A > A - 3')
      assert_includes(paths, 'CLASSIFICATION TREE > A > A - 3 > A - 3 - a')
      assert_includes(paths, 'CLASSIFICATION TREE > A > A - 3 > A - 3 - b')
      assert_includes(paths, 'CLASSIFICATION TREE > A > A - 3 > A - 3 - c')
    end
  end

  describe 'when loading descendants' do
    before do
      concept_scheme.create_concept('A')
      concept_scheme.create_concept('A', 'A - 1')
      concept_scheme.create_concept('A', 'A - 2')
      concept_scheme.create_concept('A', 'A - 3')
      concept_scheme.create_concept('A', 'A - 3', 'A - 3 - a')
      concept_scheme.create_concept('A', 'A - 3', 'A - 3 - b')
      concept_scheme.create_concept('A', 'A - 3', 'A - 3 - c')
    end

    it 'should return correct number of descendants' do
      assert_equal(6, DataCycleCore::Concept.for_tree('CLASSIFICATION TREE').with_name('A').first.descendants.count)
      assert_equal(3, DataCycleCore::Concept.for_tree('CLASSIFICATION TREE').with_name('A - 3').first.descendants.count)
    end

    it 'should return descendants with correct name' do
      names = DataCycleCore::Concept.for_tree('CLASSIFICATION TREE').with_name('A - 3')
        .first.descendants.map(&:name)

      assert(names.exclude?('A'))
      assert(names.exclude?('A - 1'))
      assert(names.exclude?('A - 2'))
      assert(names.exclude?('A - 3'))
      assert_includes(names, 'A - 3 - a')
      assert_includes(names, 'A - 3 - b')
      assert_includes(names, 'A - 3 - c')
    end
  end

  describe 'when sorting by similarity' do
    before do
      concept_scheme.create_concept('A')
      concept_scheme.create_concept('A', 'Frühling')
      concept_scheme.create_concept('A', 'Sommer')
      concept_scheme.create_concept('A', 'Sommer', 'Montag')
      concept_scheme.create_concept('A', 'Sommer', 'Dienstag')
      concept_scheme.create_concept('A', 'Sommer', 'Mittwoch')
      concept_scheme.create_concept('A', 'Sommer', 'Donnerstag')
      concept_scheme.create_concept('A', 'Sommer', 'Freitag')
      concept_scheme.create_concept('A', 'Sommer', 'Samstag')
      concept_scheme.create_concept('A', 'Sommer', 'Sonntag')
    end

    it 'should order correctly' do
      paths = DataCycleCore::Concept.for_tree('CLASSIFICATION TREE').with_name('Sommer')
        .with_descendants.order_by_similarity('Sommer').map(&:full_path)

      assert(paths[0], 'CLASSIFICATION TREE > A > Sommer')
      assert(paths[1], 'CLASSIFICATION TREE > A > Sommer > Sonntag')
      assert(paths[2], 'CLASSIFICATION TREE > A > Sommer > Samstag')
    end
  end
end
