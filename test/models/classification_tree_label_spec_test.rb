# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'
require 'minitest/autorun'
require 'helpers/minitest_spec_helper'

describe DataCycleCore::ClassificationTreeLabel do
  include DataCycleCore::MinitestSpecHelper

  def tree_one
    @tree_one ||= DataCycleCore::ClassificationTreeLabel.create!(name: 'CLASSIFICATION TREE I')
  end

  def tree_two
    @tree_two ||= DataCycleCore::ClassificationTreeLabel.create!(name: 'CLASSIFICATION TREE II')
  end

  def external_source
    @external_source ||= DataCycleCore::ExternalSystem.create!(name: 'DUMMY SOURCE')
  end

  after do
    tree_one.tap(&:reload).classification_aliases.map(&:classifications).each(&:delete_all!)
    tree_one.tap(&:reload).classification_aliases.map(&:classification_groups).each(&:delete_all!)
    tree_one.tap(&:reload).classification_aliases.delete_all!
    tree_one.tap(&:reload).classification_trees.delete_all!
    tree_one.tap(&:reload).destroy_fully!
    @tree_one = nil

    tree_two.tap(&:reload).classification_aliases.map(&:classifications).each(&:delete_all!)
    tree_two.tap(&:reload).classification_aliases.map(&:classification_groups).each(&:delete_all!)
    tree_two.tap(&:reload).classification_aliases.delete_all!
    tree_two.tap(&:reload).classification_trees.delete_all!
    tree_two.tap(&:reload).destroy_fully!
    @tree_two = nil

    external_source.delete
    @external_source = nil
  end

  it 'should create necessary objects for classifications' do
    tree_one.create_classification_alias('CLASSIFICATION 1')

    assert(tree_one.classification_aliases.size, 1)
    assert(tree_one.classification_aliases.first.name, 'CLASSIFICATION 1')

    assert(tree_one.classification_aliases.first.classifications.size, 1)
    assert(tree_one.classification_aliases.first.classifications.first.name, 'CLASSIFICATION 1')
  end

  it 'should create necessary objects for nested classifications' do
    tree_one.create_classification_alias('CLASSIFICATION I', 'CLASSIFICATION I - A', 'CLASSIFICATION I - A - 1')

    classification_aliases = tree_one.classification_aliases.roots

    assert(classification_aliases.size, 1)
    assert(classification_aliases.first.name, 'CLASSIFICATION I')

    assert(classification_aliases.first.classifications.size, 1)
    assert(classification_aliases.first.classifications.first.name, 'CLASSIFICATION I')

    classification_aliases = classification_aliases.first.sub_classification_alias

    assert(classification_aliases.size, 1)
    assert(classification_aliases.first.name, 'CLASSIFICATION I - A')

    assert(classification_aliases.first.classifications.size, 1)
    assert(classification_aliases.first.classifications.first.name, 'CLASSIFICATION I - A')

    classification_aliases = classification_aliases.first.sub_classification_alias

    assert(classification_aliases.size, 1)
    assert(classification_aliases.first.name, 'CLASSIFICATION I - A - 1')

    assert(classification_aliases.first.classifications.size, 1)
    assert(classification_aliases.first.classifications.first.name, 'CLASSIFICATION I - A - 1')
  end

  it 'should create nested classifications with external sources and keys' do
    classification_attributes = {
      name: 'CLASSIFICATION 1',
      external_source:,
      external_key: '1234'
    }
    tree_one.create_classification_alias(classification_attributes)

    assert(tree_one.classification_aliases.size, 1)
    assert(tree_one.classification_aliases.first.name, 'CLASSIFICATION 1')
    assert(tree_one.classification_aliases.first.external_source_id, external_source.id)

    assert(tree_one.classification_aliases.first.classifications.size, 1)
    assert(tree_one.classification_aliases.first.classifications.first.name, 'CLASSIFICATION 1')
    assert(tree_one.classification_aliases.first.classifications.first.external_source_id, external_source.id)
    assert(tree_one.classification_aliases.first.classifications.first.external_key, '1234')
  end

  it 'should created nested classifications with same name' do
    tree_one.create_classification_alias('CLASSIFICATION I', 'CLASSIFICATION I')

    classification_aliases = tree_one.classification_aliases.roots

    assert(classification_aliases.size, 1)
    assert(classification_aliases.first.name, 'CLASSIFICATION I')

    assert(classification_aliases.first.classifications.size, 1)
    assert(classification_aliases.first.classifications.first.name, 'CLASSIFICATION I')

    classification_aliases = classification_aliases.first.sub_classification_alias

    assert(classification_aliases.size, 1)
    assert(classification_aliases.first.name, 'CLASSIFICATION I')

    assert(classification_aliases.first.classifications.size, 1)
    assert(classification_aliases.first.classifications.first.name, 'CLASSIFICATION I')
  end

  it 'should ignore aliases from different classification trees' do
    tree_one.create_classification_alias('CLASSIFICATION I', 'CLASSIFICATION I - A')
    tree_two.create_classification_alias('CLASSIFICATION I', 'CLASSIFICATION I - A')

    assert(tree_one.classification_aliases.size, 2)
    assert(tree_two.classification_aliases.size, 2)
    tree_one.classification_aliases.each do |tree_one_alias|
      assert(tree_two.classification_aliases.map(&:id).exclude?(tree_one_alias.id))
    end
  end

  it 'should return newly created alias' do
    classification_alias = tree_one.create_classification_alias('CLASSIFICATION I', 'CLASSIFICATION I - A')

    assert_equal(false, classification_alias.new_record?)
    assert_predicate(classification_alias, :present?)
    assert(classification_alias.name, 'CLASSIFICATION I - A')
  end

  it 'create new classifications with insert_all_classifications_by_path' do
    classification_attributes = lambda { |key|
      {
        name: "CLASSIFICATION #{key}",
        external_source:,
        external_key: SecureRandom.uuid,
        uri: SecureRandom.uuid
      }
    }
    tree_one.create_classification_alias(classification_attributes.call('I'), classification_attributes.call('I - A'))
    tree_one.create_classification_alias(classification_attributes.call('I'), classification_attributes.call('I - A'))
    tree_one.create_classification_alias(classification_attributes.call('I'), classification_attributes.call('I - A'))
    tree_one.create_classification_alias(classification_attributes.call('II'), classification_attributes.call('II - A'))
    tree_one.create_classification_alias(classification_attributes.call('II'), classification_attributes.call('II - A'))
    tree_one.create_classification_alias(classification_attributes.call('II'), classification_attributes.call('II - A'))

    classifications = tree_one
      .classification_aliases
      .preload(:classification_alias_path, :primary_classification)
      .group_by { |ca| ca.classification_alias_path&.full_path_names&.reverse&.drop(1) }
      .map do |k, _v|
        {
          name: k.last,
          path: k
        }
      end

    tree_two.insert_all_classifications_by_path(classifications)

    assert_equal(12, tree_one.classification_aliases.size)
    assert_equal(4, tree_two.classification_aliases.size)

    tree_two.classification_aliases.each do |ca|
      assert_equal(1, ca.classifications.size)

      ca.classifications.each do |c|
        assert_equal(ca.internal_name, c.name)
      end
    end
  end
end
