# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'
require 'minitest/autorun'
require 'helpers/minitest_spec_helper'

describe DataCycleCore::Generic::Common::DataReferenceTransformations do
  include DataCycleCore::MinitestSpecHelper

  subject do
    DataCycleCore::Generic::Common::DataReferenceTransformations
  end

  it 'should create external reference for single content' do
    raw_data = {
      'content_id' => 'SOME EXTERNAL ID'
    }

    transformed_data = subject.add_external_content_references(raw_data, 'content', 'EXTERNAL SOURCE ID', 'content_id')

    assert_equal(1, transformed_data['content'].size)

    assert_equal('EXTERNAL SOURCE ID', transformed_data['content'].first.external_source_id)
    assert_equal('SOME EXTERNAL ID', transformed_data['content'].first.external_key)
  end

  it 'should create external references for multiple contents' do
    raw_data = {
      'contents' => [
        { 'id' => 'EXTERNAL ID ONE' },
        { 'id' => 'EXTERNAL ID TWO' },
        { 'id' => 'EXTERNAL ID THREE' }
      ]
    }

    transformed_data = subject.add_external_content_references(raw_data, 'content', 'EXTERNAL SOURCE ID', ['contents', 'id'])

    assert_equal(3, transformed_data['content'].size)

    assert_equal(1, transformed_data['content'].map(&:external_source_id).uniq.size)
    assert_equal('EXTERNAL SOURCE ID', transformed_data['content'].map(&:external_source_id).first)

    assert_equal(3, transformed_data['content'].map(&:external_key).uniq.size)
    assert_includes(transformed_data['content'].map(&:external_key).uniq, 'EXTERNAL ID ONE')
    assert_includes(transformed_data['content'].map(&:external_key).uniq, 'EXTERNAL ID TWO')
    assert_includes(transformed_data['content'].map(&:external_key).uniq, 'EXTERNAL ID THREE')
  end

  it 'should create external references for deeply nested contents' do
    raw_data = {
      'contents_1' => [
        {
          'contents_2' => [
            {
              'contents_3' => [
                { 'id' => 'SOME EXTERNAL ID' },
                { 'id' => 'ANOTHER EXTERNAL ID' }
              ]
            }
          ]
        }
      ]
    }

    transformed_data = subject.add_external_content_references(raw_data, 'content', 'EXTERNAL SOURCE ID',
                                                               ['contents_1', 'contents_2', 'contents_3', 'id'])

    assert_equal(2, transformed_data['content'].size)

    assert_equal(1, transformed_data['content'].map(&:external_source_id).uniq.size)
    assert_equal('EXTERNAL SOURCE ID', transformed_data['content'].map(&:external_source_id).first)

    assert_equal(2, transformed_data['content'].map(&:external_key).uniq.size)
    assert_includes(transformed_data['content'].map(&:external_key).uniq, 'SOME EXTERNAL ID')
    assert_includes(transformed_data['content'].map(&:external_key).uniq, 'ANOTHER EXTERNAL ID')
  end

  it 'should create external classification references' do
    raw_data = {
      'classifications_1' => [
        {
          'classifications_1_1' => [
            {
              'classifications_1_1_1' => [
                { 'id' => 'EXTERNAL ID ONE' },
                { 'id' => 'EXTERNAL ID TWO' }
              ]
            }
          ]
        }
      ],
      'classification_ids_2' => [
        { 'id' => 'EXTERNAL ID THREE' },
        { 'id' => 'EXTERNAL ID FOUR' },
        { 'id' => 'EXTERNAL ID FIVE' }
      ]
    }

    transformed_data = subject.add_external_classification_references(
      raw_data, 'classifications_1', 'EXTERNAL SOURCE ID',
      ['classifications_1', 'classifications_1_1', 'classifications_1_1_1', 'id']
    )
    transformed_data = subject.add_external_classification_references(
      transformed_data, 'classifications_2', 'EXTERNAL SOURCE ID', ['classification_ids_2', 'id']
    )

    assert_equal(2, transformed_data['classifications_1'].size)

    assert_equal(1, transformed_data['classifications_1'].map(&:external_source_id).uniq.size)
    assert_equal('EXTERNAL SOURCE ID', transformed_data['classifications_1'].map(&:external_source_id).first)

    assert_equal(2, transformed_data['classifications_1'].map(&:external_key).uniq.size)
    assert_includes(transformed_data['classifications_1'].map(&:external_key).uniq, 'EXTERNAL ID ONE')
    assert_includes(transformed_data['classifications_1'].map(&:external_key).uniq, 'EXTERNAL ID TWO')

    assert_equal(3, transformed_data['classifications_2'].size)

    assert_equal(1, transformed_data['classifications_2'].map(&:external_source_id).uniq.size)
    assert_equal('EXTERNAL SOURCE ID', transformed_data['classifications_2'].map(&:external_source_id).first)

    assert_equal(3, transformed_data['classifications_2'].map(&:external_key).uniq.size)
    assert_includes(transformed_data['classifications_2'].map(&:external_key).uniq, 'EXTERNAL ID THREE')
    assert_includes(transformed_data['classifications_2'].map(&:external_key).uniq, 'EXTERNAL ID FOUR')
    assert_includes(transformed_data['classifications_2'].map(&:external_key).uniq, 'EXTERNAL ID FIVE')
  end

  it 'should create classification name references for nested attributes' do
    raw_data = {
      'classifications' => {
        'seasons' => [
          { 'name' => 'Sommer', 'icon' => 'summer.gif' },
          { 'name' => 'Winter', 'icon' => 'winter.gif' }
        ]
      }
    }

    transformed_data = subject.add_classification_name_references(
      raw_data, 'seasons', 'Jahreszeiten', ['classifications', 'seasons', 'name']
    )

    assert_equal(2, transformed_data['seasons'].size)
    assert_includes(transformed_data['seasons'].map(&:classification_path).uniq, ['Jahreszeiten', 'Sommer'])
    assert_includes(transformed_data['seasons'].map(&:classification_path).uniq, ['Jahreszeiten', 'Winter'])
  end

  it 'should create classification uri references for nested attributes' do
    raw_data = {
      'classifications' => {
        'weekdays' => [
          { 'name' => 'Montag', 'uri' => 'https://schema.org/Monday' },
          { 'name' => 'Dienstag', 'uri' => 'https://schema.org/Tuesday' }
        ]
      }
    }

    transformed_data = subject.add_classification_uri_references(
      raw_data, 'days', 'Wochentage', ['classifications', 'weekdays', 'uri']
    )

    assert_equal(2, transformed_data['days'].size)
    assert_includes(transformed_data['days'].map(&:classification_identifier).uniq, ['Wochentage', 'https://schema.org/Monday'])
    assert_includes(transformed_data['days'].map(&:classification_identifier).uniq, ['Wochentage', 'https://schema.org/Tuesday'])
  end

  it 'should create external references using lambdas' do
    raw_data = {
      'content' => ['some external id', 'another external id']
    }

    transformed_data = subject.add_external_classification_references(
      raw_data, 'content', 'EXTERNAL SOURCE ID',
      ->(data) { data['content'].map(&:upcase) }
    )

    assert_equal(2, transformed_data['content'].map(&:external_key).uniq.size)
    assert_includes(transformed_data['content'].map(&:external_key).uniq, 'SOME EXTERNAL ID')
    assert_includes(transformed_data['content'].map(&:external_key).uniq, 'ANOTHER EXTERNAL ID')
  end

  it 'should create classification name references using lambdas' do
    raw_data = {
      'seasons' => ['sommer', 'herbst']
    }

    transformed_data = subject.add_classification_name_references(
      raw_data, 'seasons', 'Jahreszeiten',
      ->(data) { data['seasons'].map(&:capitalize) }
    )

    assert_equal(2, transformed_data['seasons'].size)
    assert_includes(transformed_data['seasons'].map(&:classification_path).uniq, ['Jahreszeiten', 'Sommer'])
    assert_includes(transformed_data['seasons'].map(&:classification_path).uniq, ['Jahreszeiten', 'Herbst'])
  end

  it 'should create classification uri references using lambdas' do
    raw_data = {
      'weekdays' => ['https://schema.org/Monday', 'https://schema.org/Tuesday']
    }

    transformed_data = subject.add_classification_uri_references(
      raw_data, 'weekdays', 'Wochentage',
      ->(data) { data['weekdays'] }
    )

    assert_equal(2, transformed_data['weekdays'].size)
    assert_includes(transformed_data['weekdays'].map(&:classification_identifier).uniq, ['Wochentage', 'https://schema.org/Monday'])
    assert_includes(transformed_data['weekdays'].map(&:classification_identifier).uniq, ['Wochentage', 'https://schema.org/Tuesday'])
  end

  it 'should use optional mapping table when creating classification name references' do
    raw_data = {
      'seasons' => ['summer', 'autmn']
    }

    transformed_data = subject.add_classification_name_references(
      raw_data, 'seasons', 'Jahreszeiten', 'seasons',
      {
        'spring' => 'Frühling',
        'summer' => 'Sommer',
        'autmn' => 'Herbst',
        'winter' => 'Winter'
      }
    )

    assert_equal(2, transformed_data['seasons'].size)
    assert_includes(transformed_data['seasons'].map(&:classification_path).uniq, ['Jahreszeiten', 'Sommer'])
    assert_includes(transformed_data['seasons'].map(&:classification_path).uniq, ['Jahreszeiten', 'Herbst'])
  end

  it 'should add universal classifications instead of replacing them' do
    raw_data = {
      'classifications_1' => 'EXTERNAL ID ONE',
      'classifications_2' => ['EXTERNAL ID TWO'],
      'classifications_3' => ['EXTERNAL ID THREE']
    }

    transformed_data = subject.add_external_classification_references(
      raw_data, 'universal_classifications', 'EXTERNAL SOURCE ID', 'classifications_1'
    )
    transformed_data = subject.add_external_classification_references(
      transformed_data, 'universal_classifications', 'EXTERNAL SOURCE ID', 'classifications_2'
    )
    transformed_data = subject.add_external_classification_references(
      transformed_data, 'universal_classifications', 'EXTERNAL SOURCE ID', 'classifications_3'
    )

    assert_equal(3, transformed_data['universal_classifications'].map(&:external_key).uniq.size)
    assert_includes(transformed_data['universal_classifications'].map(&:external_key).uniq, 'EXTERNAL ID ONE')
    assert_includes(transformed_data['universal_classifications'].map(&:external_key).uniq, 'EXTERNAL ID TWO')
    assert_includes(transformed_data['universal_classifications'].map(&:external_key).uniq, 'EXTERNAL ID THREE')
  end

  it 'should add universal classifications instead of replacing them for classification name references' do
    raw_data = {
      'classifications_1' => ['Some Name'],
      'classifications_2' => ['Another Name']
    }

    transformed_data = subject.add_classification_name_references(
      raw_data, 'universal_classifications', 'Some Tree', 'classifications_1'
    )
    transformed_data = subject.add_classification_name_references(
      transformed_data, 'universal_classifications', 'Another Tree', 'classifications_2'
    )

    assert_equal(2, transformed_data['universal_classifications'].map(&:classification_path).uniq.size)
    assert_includes(transformed_data['universal_classifications'].map(&:classification_path).uniq, ['Some Tree', 'Some Name'])
    assert_includes(transformed_data['universal_classifications'].map(&:classification_path).uniq, ['Another Tree', 'Another Name'])
  end

  it 'should create external reference for single schedule' do
    raw_data = {
      'schedule_id' => 'SOME EXTERNAL ID'
    }

    transformed_data = subject.add_external_schedule_references(raw_data, 'schedule', 'EXTERNAL SOURCE ID', 'schedule_id')

    assert_equal(1, transformed_data['schedule'].size)

    assert_equal('EXTERNAL SOURCE ID', transformed_data['schedule'].first.external_source_id)
    assert_equal('SOME EXTERNAL ID', transformed_data['schedule'].first.external_key)
  end

  it 'should create external references for multiple schedules' do
    raw_data = {
      'schedules' => [
        { 'id' => 'EXTERNAL ID ONE' },
        { 'id' => 'EXTERNAL ID TWO' },
        { 'id' => 'EXTERNAL ID THREE' }
      ]
    }

    transformed_data = subject.add_external_schedule_references(raw_data, 'schedule', 'EXTERNAL SOURCE ID', ['schedules', 'id'])

    assert_equal(3, transformed_data['schedule'].size)

    assert_equal(1, transformed_data['schedule'].map(&:external_source_id).uniq.size)
    assert_equal('EXTERNAL SOURCE ID', transformed_data['schedule'].map(&:external_source_id).first)

    assert_equal(3, transformed_data['schedule'].map(&:external_key).uniq.size)
    assert_includes(transformed_data['schedule'].map(&:external_key).uniq, 'EXTERNAL ID ONE')
    assert_includes(transformed_data['schedule'].map(&:external_key).uniq, 'EXTERNAL ID TWO')
    assert_includes(transformed_data['schedule'].map(&:external_key).uniq, 'EXTERNAL ID THREE')
  end

  it 'should create external references for deeply nested schedules' do
    raw_data = {
      'contents_1' => [
        {
          'contents_2' => [
            {
              'schedules' => [
                { 'id' => 'SOME EXTERNAL ID' },
                { 'id' => 'ANOTHER EXTERNAL ID' }
              ]
            }
          ]
        }
      ]
    }

    transformed_data = subject.add_external_schedule_references(raw_data, 'schedule', 'EXTERNAL SOURCE ID',
                                                                ['contents_1', 'contents_2', 'schedules', 'id'])

    assert_equal(2, transformed_data['schedule'].size)

    assert_equal(1, transformed_data['schedule'].map(&:external_source_id).uniq.size)
    assert_equal('EXTERNAL SOURCE ID', transformed_data['schedule'].map(&:external_source_id).first)

    assert_equal(2, transformed_data['schedule'].map(&:external_key).uniq.size)
    assert_includes(transformed_data['schedule'].map(&:external_key).uniq, 'SOME EXTERNAL ID')
    assert_includes(transformed_data['schedule'].map(&:external_key).uniq, 'ANOTHER EXTERNAL ID')
  end

  it 'should return external reference for single schedule' do
    raw_data = {
      'schedule_id' => 'SOME EXTERNAL ID'
    }

    transformed_data = subject.get_external_schedule_references(raw_data, 'EXTERNAL SOURCE ID', 'schedule_id')

    assert(transformed_data.present?)

    assert_equal('EXTERNAL SOURCE ID', transformed_data.first.external_source_id)
    assert_equal('SOME EXTERNAL ID', transformed_data.first.external_key)
  end

  it 'should return external reference for single content' do
    raw_data = {
      'content_id' => 'SOME EXTERNAL ID'
    }

    transformed_data = subject.get_external_content_references(raw_data, 'EXTERNAL SOURCE ID', 'content_id')

    assert(transformed_data.present?)

    assert_equal('EXTERNAL SOURCE ID', transformed_data.first.external_source_id)
    assert_equal('SOME EXTERNAL ID', transformed_data.first.external_key)
  end

  it 'should return external reference for single classification' do
    raw_data = {
      'classifications' => 'SOME EXTERNAL ID'
    }

    transformed_data = subject.get_classification_name_references(raw_data, 'Jahreszeiten', 'classifications')

    assert(transformed_data.present?)

    assert_equal('Jahreszeiten', transformed_data.first.tree_name)
    assert_equal('SOME EXTERNAL ID', transformed_data.first.classification_name)
  end

  it 'should resolve external schedule references' do
    raw_data = {
      'contents_1' => [
        {
          'contents_2' => [
            {
              'schedules' => [
                { 'id' => 'SOME EXTERNAL ID' },
                { 'id' => 'ANOTHER EXTERNAL ID' }
              ]
            }
          ]
        }
      ]
    }

    transformed_data = subject.add_external_schedule_references(raw_data, 'schedule', 'EXTERNAL SOURCE ID',
                                                                ['contents_1', 'contents_2', 'schedules', 'id'])

    load_schedules_stub = lambda do |_external_source_id, _external_keys|
      {
        'SOME EXTERNAL ID' => '00000000-0000-0000-0000-000000000001',
        'ANOTHER EXTERNAL ID' => '00000000-0000-0000-0000-000000000002'
      }
    end

    subject.stub :load_schedules, load_schedules_stub do
      transformed_data = subject.resolve_references(transformed_data)

      assert_equal(2, transformed_data['schedule'].size)
      assert_includes(transformed_data['schedule'], '00000000-0000-0000-0000-000000000001')
      assert_includes(transformed_data['schedule'], '00000000-0000-0000-0000-000000000002')
    end
  end

  it 'should resolve external content references' do
    raw_data = {
      'contents_1' => [
        {
          'contents_2' => [
            {
              'contents_3' => [
                { 'id' => 'SOME EXTERNAL ID' },
                { 'id' => 'ANOTHER EXTERNAL ID' }
              ]
            }
          ]
        }
      ],
      'additional_content' => { 'id' => 'SOME ADDITIONAL EXTERNAL ID' }
    }

    transformed_data = subject.add_external_content_references(raw_data, 'content', 'EXTERNAL SOURCE ID',
                                                               ['contents_1', 'contents_2', 'contents_3', 'id'])
    transformed_data = subject.add_external_content_references(transformed_data, 'additional_content', 'EXTERNAL SOURCE ID',
                                                               ['additional_content', 'id'])

    load_things_stub = lambda do |_external_source_id, _external_keys|
      {
        'SOME EXTERNAL ID' => '00000000-0000-0000-0000-000000000001',
        'ANOTHER EXTERNAL ID' => '00000000-0000-0000-0000-000000000002',
        'SOME ADDITIONAL EXTERNAL ID' => '00000000-0000-0000-0000-000000000003'
      }
    end

    subject.stub :load_things, load_things_stub do
      transformed_data = subject.resolve_references(transformed_data)

      assert_equal(2, transformed_data['content'].size)
      assert_includes(transformed_data['content'], '00000000-0000-0000-0000-000000000001')
      assert_includes(transformed_data['content'], '00000000-0000-0000-0000-000000000002')

      assert_equal(1, transformed_data['additional_content'].size)
      assert_includes(transformed_data['additional_content'], '00000000-0000-0000-0000-000000000003')
    end
  end

  it 'should resolve external content references and handle duplicates' do
    # possible when both external_keys are marked as duplicates
    raw_data = {
      'contents_1' => [
        { 'id' => 'SOME EXTERNAL ID' },
        { 'id' => 'ANOTHER EXTERNAL ID' }
      ],
      'additional_content' => { 'id' => 'SOME ADDITIONAL EXTERNAL ID' }
    }

    transformed_data = subject.add_external_content_references(raw_data, 'content', 'EXTERNAL SOURCE ID', ['contents_1', 'id'])

    load_things_stub = lambda do |_external_source_id, _external_keys|
      {
        'SOME EXTERNAL ID' => '00000000-0000-0000-0000-000000000001',
        'ANOTHER EXTERNAL ID' => '00000000-0000-0000-0000-000000000001'
      }
    end

    subject.stub :load_things, load_things_stub do
      transformed_data = subject.resolve_references(transformed_data)

      assert_equal(1, transformed_data['content'].size)
      assert_includes(transformed_data['content'], '00000000-0000-0000-0000-000000000001')
    end
  end

  it 'should resolve external classification references' do
    raw_data = {
      'classification_1' => [
        {
          'classification_2' => [
            {
              'classification_3' => [
                { 'id' => 'SOME EXTERNAL ID' },
                { 'id' => 'ANOTHER EXTERNAL ID' }
              ]
            }
          ]
        }
      ],
      'additional_classification' => { 'id' => 'SOME ADDITIONAL EXTERNAL ID' }
    }

    transformed_data = subject.add_external_classification_references(raw_data, 'classification', 'EXTERNAL SOURCE ID',
                                                                      ['classification_1', 'classification_2', 'classification_3', 'id'])
    transformed_data = subject.add_external_classification_references(transformed_data, 'additional_classification', 'EXTERNAL SOURCE ID',
                                                                      ['additional_classification', 'id'])

    load_classifications_stub = lambda do |_external_source_id, _external_keys|
      {
        'SOME EXTERNAL ID' => '00000000-0000-0000-0000-000000000001',
        'ANOTHER EXTERNAL ID' => '00000000-0000-0000-0000-000000000002',
        'SOME ADDITIONAL EXTERNAL ID' => '00000000-0000-0000-0000-000000000003'
      }
    end

    subject.stub :load_classifications, load_classifications_stub do
      transformed_data = subject.resolve_references(transformed_data)

      assert_equal(2, transformed_data['classification'].size)
      assert_includes(transformed_data['classification'], '00000000-0000-0000-0000-000000000001')
      assert_includes(transformed_data['classification'], '00000000-0000-0000-0000-000000000002')

      assert_equal(1, transformed_data['additional_classification'].size)
      assert_includes(transformed_data['additional_classification'], '00000000-0000-0000-0000-000000000003')
    end
  end

  it 'should resolve classification name references' do
    raw_data = {
      'seasons' => ['sommer', 'herbst']
    }

    transformed_data = subject.add_classification_name_references(
      raw_data, 'classifications', 'Jahreszeiten',
      ->(data) { data['seasons'].map(&:capitalize) }
    )

    load_classifications_by_path_stub = lambda do |_classification_paths|
      {
        ['Jahreszeiten', 'Sommer'] => '00000000-0000-0000-0000-000000000001',
        ['Jahreszeiten', 'Herbst'] => '00000000-0000-0000-0000-000000000002'
      }
    end

    subject.stub :load_classifications_by_path, load_classifications_by_path_stub do
      transformed_data = subject.resolve_references(transformed_data)

      assert_equal(2, transformed_data['classifications'].size)
      assert_includes(transformed_data['classifications'], '00000000-0000-0000-0000-000000000001')
      assert_includes(transformed_data['classifications'], '00000000-0000-0000-0000-000000000002')
    end
  end

  it 'should resolve classification uri references' do
    raw_data = {
      'weekdays' => ['https://schema.org/Monday', 'https://schema.org/Tuesday']
    }

    transformed_data = subject.add_classification_name_references(
      raw_data, 'classifications', 'Wochentage',
      ->(data) { data['weekdays'] }
    )

    load_classifications_uri_stub = lambda do |_classification_identifiers|
      {
        ['Wochentage', 'https://schema.org/Monday'] => '00000000-0000-0000-0000-000000000001',
        ['Wochentage', 'https://schema.org/Tuesday'] => '00000000-0000-0000-0000-000000000002'
      }
    end

    subject.stub :load_classifications_by_uri, load_classifications_uri_stub do
      transformed_data = subject.resolve_references(transformed_data)

      assert_equal(2, transformed_data['classifications'].size)
      assert_includes(transformed_data['classifications'], '00000000-0000-0000-0000-000000000001')
      assert_includes(transformed_data['classifications'], '00000000-0000-0000-0000-000000000002')
    end
  end

  it 'should resolve mixed external references' do
    raw_data = {
      'content' => { 'id' => 'EXTERNAL CONTENT ID' },
      'classification' => { 'id' => 'EXTERNAL CLASSIFICATION ID' },
      'seasons' => ['sommer', 'herbst']
    }

    transformed_data = subject.add_external_classification_references(raw_data, 'classification', 'EXTERNAL SOURCE ID',
                                                                      ['classification', 'id'])
    transformed_data = subject.add_external_content_references(transformed_data, 'content', 'EXTERNAL SOURCE ID',
                                                               ['content', 'id'])
    transformed_data = subject.add_classification_name_references(transformed_data, 'seasons', 'Jahreszeiten',
                                                                  ->(data) { data['seasons'].map(&:capitalize) })

    load_data_stub = lambda do |_reference_type, _external_source_id, _external_keys|
      {
        'EXTERNAL CONTENT ID' => '00000000-0000-0000-0000-000000000001',
        'EXTERNAL CLASSIFICATION ID' => '00000000-0000-0000-0001-000000000002'
      }
    end
    load_classifications_by_path_stub = lambda do |_classification_paths|
      {
        ['Jahreszeiten', 'Sommer'] => '00000000-0000-0000-0002-000000000001',
        ['Jahreszeiten', 'Herbst'] => '00000000-0000-0000-0002-000000000002'
      }
    end

    subject.stub :load_data, load_data_stub do
      subject.stub :load_classifications_by_path, load_classifications_by_path_stub do
        transformed_data = subject.resolve_references(transformed_data)

        assert_equal(1, transformed_data['content'].size)
        assert_includes(transformed_data['content'], '00000000-0000-0000-0000-000000000001')

        assert_equal(1, transformed_data['classification'].size)
        assert_includes(transformed_data['classification'], '00000000-0000-0000-0001-000000000002')

        assert_equal(2, transformed_data['seasons'].size)
        assert_includes(transformed_data['seasons'], '00000000-0000-0000-0002-000000000001')
        assert_includes(transformed_data['seasons'], '00000000-0000-0000-0002-000000000002')
      end
    end
  end

  describe '#load_classifications_by_path' do
    def classification_tree_one
      @classification_tree_one ||= DataCycleCore::ClassificationTreeLabel.create!(name: 'CLASSIFICATION TREE ONE')
    end

    def classification_tree_two
      @classification_tree_two ||= DataCycleCore::ClassificationTreeLabel.create!(name: 'CLASSIFICATION TREE TWO')
    end

    before do
      subject.instance_variable_set(:@preloadable_classification_trees, nil)
      subject.clear_peloaded_mappings

      classification_tree_one.create_classification_alias('A')
      classification_tree_one.create_classification_alias('B')
      classification_tree_one.create_classification_alias('C')

      classification_tree_two.create_classification_alias('I')
    end

    after do
      classification_tree_one.tap(&:reload).classification_aliases.map(&:classifications).each(&:delete_all!)
      classification_tree_one.tap(&:reload).classification_aliases.map(&:classification_groups).each(&:delete_all!)
      classification_tree_one.tap(&:reload).classification_aliases.delete_all!
      classification_tree_one.tap(&:reload).classification_trees.delete_all!
      classification_tree_one.tap(&:reload).destroy_fully!
      @classification_tree_one = nil

      classification_tree_two.tap(&:reload).classification_aliases.map(&:classifications).each(&:delete_all!)
      classification_tree_two.tap(&:reload).classification_aliases.map(&:classification_groups).each(&:delete_all!)
      classification_tree_two.tap(&:reload).classification_aliases.delete_all!
      classification_tree_two.tap(&:reload).classification_trees.delete_all!
      classification_tree_two.tap(&:reload).destroy_fully!
      @classification_tree_two = nil
    end

    it 'should handle empty classification paths' do
      mapping_table = subject.load_classifications_by_path([])

      assert_equal({}, mapping_table)
    end

    it 'should create mapping table for single classification' do
      mapping_table = subject.load_classifications_by_path([['CLASSIFICATION TREE ONE', 'A']])

      assert_equal(1, mapping_table.size)
      assert_equal(
        DataCycleCore::ClassificationAlias.classification_for_tree_with_name('CLASSIFICATION TREE ONE', 'A'),
        mapping_table[['CLASSIFICATION TREE ONE', 'A']]
      )
    end

    it 'should create mapping table for multiple classifications from same tree' do
      mapping_table = subject.load_classifications_by_path(
        [
          ['CLASSIFICATION TREE ONE', 'A'],
          ['CLASSIFICATION TREE ONE', 'B'],
          ['CLASSIFICATION TREE ONE', 'C']
        ]
      )

      assert_equal(3, mapping_table.size)
      assert_equal(
        DataCycleCore::ClassificationAlias.classification_for_tree_with_name('CLASSIFICATION TREE ONE', 'A'),
        mapping_table[['CLASSIFICATION TREE ONE', 'A']]
      )
      assert_equal(
        DataCycleCore::ClassificationAlias.classification_for_tree_with_name('CLASSIFICATION TREE ONE', 'B'),
        mapping_table[['CLASSIFICATION TREE ONE', 'B']]
      )
      assert_equal(
        DataCycleCore::ClassificationAlias.classification_for_tree_with_name('CLASSIFICATION TREE ONE', 'C'),
        mapping_table[['CLASSIFICATION TREE ONE', 'C']]
      )
    end

    it 'should create mapping table for multiple classifications from multiple trees' do
      mapping_table = subject.load_classifications_by_path(
        [
          ['CLASSIFICATION TREE ONE', 'A'],
          ['CLASSIFICATION TREE ONE', 'B'],
          ['CLASSIFICATION TREE TWO', 'I']
        ]
      )

      assert_equal(3, mapping_table.size)
      assert_equal(
        DataCycleCore::ClassificationAlias.classification_for_tree_with_name('CLASSIFICATION TREE ONE', 'A'),
        mapping_table[['CLASSIFICATION TREE ONE', 'A']]
      )
      assert_equal(
        DataCycleCore::ClassificationAlias.classification_for_tree_with_name('CLASSIFICATION TREE ONE', 'B'),
        mapping_table[['CLASSIFICATION TREE ONE', 'B']]
      )
      assert_equal(
        DataCycleCore::ClassificationAlias.classification_for_tree_with_name('CLASSIFICATION TREE TWO', 'I'),
        mapping_table[['CLASSIFICATION TREE TWO', 'I']]
      )
    end

    it 'should preload given classification trees as a whole' do
      subject.instance_variable_set(:@preloadable_classification_trees, ['CLASSIFICATION TREE ONE'])

      mapping_table = subject.load_classifications_by_path([['CLASSIFICATION TREE ONE', 'A']])

      assert_equal(3, mapping_table.size)
      assert_equal(
        DataCycleCore::ClassificationAlias.classification_for_tree_with_name('CLASSIFICATION TREE ONE', 'A'),
        mapping_table[['CLASSIFICATION TREE ONE', 'A']]
      )
    end

    it 'should handle a combination of preloaded an not preloaded classifications' do
      subject.instance_variable_set(:@preloadable_classification_trees, ['CLASSIFICATION TREE ONE'])

      mapping_table = subject.load_classifications_by_path(
        [
          ['CLASSIFICATION TREE ONE', 'A'],
          ['CLASSIFICATION TREE TWO', 'I']
        ]
      )

      assert_equal(4, mapping_table.size)
      assert_equal(
        DataCycleCore::ClassificationAlias.classification_for_tree_with_name('CLASSIFICATION TREE ONE', 'A'),
        mapping_table[['CLASSIFICATION TREE ONE', 'A']]
      )
      assert_equal(
        DataCycleCore::ClassificationAlias.classification_for_tree_with_name('CLASSIFICATION TREE TWO', 'I'),
        mapping_table[['CLASSIFICATION TREE TWO', 'I']]
      )
    end

    it 'should resolve external content references with non-string keys' do
      raw_data = {
        'contents_1' => [
          {
            'contents_2' => [
              {
                'contents_3' => [
                  { 'id' => 2 },
                  { 'id' => 4 }
                ]
              }
            ]
          }
        ],
        'additional_content' => { 'id' => 'SOME ADDITIONAL EXTERNAL ID' }
      }

      transformed_data = subject.add_external_content_references(raw_data, 'content', 'EXTERNAL SOURCE ID',
                                                                 ['contents_1', 'contents_2', 'contents_3', 'id'])
      transformed_data = subject.add_external_content_references(transformed_data, 'additional_content', 'EXTERNAL SOURCE ID',
                                                                 ['additional_content', 'id'])

      load_things_stub = lambda do |_external_source_id, _external_keys|
        {
          '2' => '00000000-0000-0000-0000-000000000001',
          '4' => '00000000-0000-0000-0000-000000000002',
          'SOME ADDITIONAL EXTERNAL ID' => '00000000-0000-0000-0000-000000000003'
        }
      end

      subject.stub :load_things, load_things_stub do
        transformed_data = subject.resolve_references(transformed_data)

        assert_equal(2, transformed_data['content'].size)
        assert_includes(transformed_data['content'], '00000000-0000-0000-0000-000000000001')
        assert_includes(transformed_data['content'], '00000000-0000-0000-0000-000000000002')

        assert_equal(1, transformed_data['additional_content'].size)
        assert_includes(transformed_data['additional_content'], '00000000-0000-0000-0000-000000000003')
      end
    end
  end
end
