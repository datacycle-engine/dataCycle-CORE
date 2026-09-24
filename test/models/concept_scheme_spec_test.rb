# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'
require 'minitest/autorun'
require 'helpers/minitest_spec_helper'

describe DataCycleCore::ConceptScheme do
  include DataCycleCore::MinitestSpecHelper

  def tree_one
    @tree_one ||= DataCycleCore::ConceptScheme.create!(name: 'CLASSIFICATION TREE I')
  end

  def tree_two
    @tree_two ||= DataCycleCore::ConceptScheme.create!(name: 'CLASSIFICATION TREE II')
  end

  def external_system
    @external_system ||= DataCycleCore::ExternalSystem.create!(name: 'DUMMY SOURCE')
  end

  after do
    tree_one.reload.destroy
    @tree_one = nil

    tree_two.reload.destroy
    @tree_two = nil

    external_system.delete
    @external_system = nil
  end

  it 'should create a concept' do
    tree_one.create_concept('CLASSIFICATION 1')

    assert_equal(1, tree_one.concepts.size)
    assert_equal('CLASSIFICATION 1', tree_one.concepts.first.name)
  end

  it 'should create nested concepts' do
    tree_one.create_concept('CLASSIFICATION I', 'CLASSIFICATION I - A', 'CLASSIFICATION I - A - 1')

    concepts = tree_one.concepts.roots

    assert_equal(1, concepts.size)
    assert_equal('CLASSIFICATION I', concepts.first.name)

    concepts = concepts.first.children

    assert_equal(1, concepts.size)
    assert_equal('CLASSIFICATION I - A', concepts.first.name)

    concepts = concepts.first.children

    assert_equal(1, concepts.size)
    assert_equal('CLASSIFICATION I - A - 1', concepts.first.name)
  end

  it 'should create a concept with an external system and key' do
    concept_attributes = {
      name: 'CLASSIFICATION 1',
      external_system: external_system,
      external_key: '1234'
    }
    tree_one.create_concept(concept_attributes)

    assert_equal(1, tree_one.concepts.size)
    assert_equal('CLASSIFICATION 1', tree_one.concepts.first.name)
    assert_equal(external_system.id, tree_one.concepts.first.external_system_id)
    assert_equal('1234', tree_one.concepts.first.external_key)
  end

  it 'should create nested concepts with the same name' do
    tree_one.create_concept('CLASSIFICATION I', 'CLASSIFICATION I')

    concepts = tree_one.concepts.roots

    assert_equal(1, concepts.size)
    assert_equal('CLASSIFICATION I', concepts.first.name)

    concepts = concepts.first.children

    assert_equal(1, concepts.size)
    assert_equal('CLASSIFICATION I', concepts.first.name)
  end

  it 'should ignore concepts from different concept schemes' do
    tree_one.create_concept('CLASSIFICATION I', 'CLASSIFICATION I - A')
    tree_two.create_concept('CLASSIFICATION I', 'CLASSIFICATION I - A')

    assert_equal(2, tree_one.concepts.size)
    assert_equal(2, tree_two.concepts.size)
    tree_one.concepts.each do |concept|
      assert(tree_two.concepts.map(&:id).exclude?(concept.id))
    end
  end

  it 'should return the newly created concept' do
    concept = tree_one.create_concept('CLASSIFICATION I', 'CLASSIFICATION I - A')

    assert_not(concept.new_record?)
    assert_predicate(concept, :present?)
    assert(concept.name, 'CLASSIFICATION I - A')
  end

  it 'creates new concepts with insert_all_concepts_by_path' do
    concept_attributes = lambda { |key|
      {
        name: "CLASSIFICATION #{key}",
        external_system: external_system,
        external_key: SecureRandom.uuid,
        uri: SecureRandom.uuid
      }
    }
    tree_one.create_concept(concept_attributes.call('I'), concept_attributes.call('I - A'))
    tree_one.create_concept(concept_attributes.call('I'), concept_attributes.call('I - A'))
    tree_one.create_concept(concept_attributes.call('I'), concept_attributes.call('I - A'))
    tree_one.create_concept(concept_attributes.call('II'), concept_attributes.call('II - A'))
    tree_one.create_concept(concept_attributes.call('II'), concept_attributes.call('II - A'))
    tree_one.create_concept(concept_attributes.call('II'), concept_attributes.call('II - A'))

    paths = tree_one
      .concepts
      .preload(:concept_path)
      .group_by { |concept| concept.concept_path&.full_path_names&.reverse&.drop(1) }
      .map do |k, _v|
        {
          name: k.last,
          path: k
        }
      end

    tree_two.insert_all_concepts_by_path(paths)

    assert_equal(12, tree_one.concepts.size)
    assert_equal(4, tree_two.concepts.size)

    tree_two.concepts.each do |concept|
      assert_equal(concept.internal_name, concept.name)
    end
  end

  it 'insert_all_concepts_by_path does nothing for an empty list' do
    assert_nil(tree_one.insert_all_concepts_by_path([]))
    assert_empty(tree_one.concepts)
  end
end
