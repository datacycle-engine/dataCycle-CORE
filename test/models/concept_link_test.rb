# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class ConceptLinkTest < DataCycleCore::TestCases::ActiveSupportTestCase
    def create_classification(tree_label, name, description = nil, external_source_id = nil, parent = nil)
      ca = ClassificationAlias.create(name:, description:, external_source_id:)
      c = Classification.create(name:, description:, external_source_id:, external_key: name)
      ClassificationGroup.create(classification_id: c.id, classification_alias_id: ca.id, external_source_id:)
      ClassificationTree.create(parent_classification_alias_id: parent&.id, classification_alias_id: ca.id, classification_tree_label_id: tree_label.id, external_source_id:)

      ca
    end

    before(:all) do
      @es_id = ExternalSystem.first.id
      @ctl1 = ClassificationTreeLabel.create(name: SecureRandom.hex(10), external_source_id: @es_id)

      @ca1 = create_classification(@ctl1, SecureRandom.hex(10), SecureRandom.hex(20), @es_id)
      @ca2 = create_classification(@ctl1, SecureRandom.hex(10), SecureRandom.hex(20), @es_id, @ca1)
    end

    test 'concept gets correct classification_id' do
      concept = Concept.find(@ca1.id)

      assert_equal @ca1.primary_classification.id, concept.classification_id
    end

    test 'concept gets correct external_key' do
      concept1 = Concept.find(@ca1.id)
      concept2 = Concept.find(@ca2.id)

      assert_equal @ca1.primary_classification.external_key, concept1.external_key
      assert_equal @ca2.primary_classification.external_key, concept2.external_key
    end

    test 'concept gets correct classification_id with insert_all_classifications_by_path' do
      name = SecureRandom.hex(10)
      cs = ConceptScheme.find(@ctl1.id)
      cs.insert_all_classifications_by_path([{ path: [name] }])
      ca = ClassificationAlias.by_full_paths("#{@ctl1.name} > #{name}").first
      concept = Concept.find(ca.id)

      assert_equal ca.primary_classification.id, concept.classification_id
    end

    test 'concept has correct concept_scheme_id' do
      concept1 = Concept.find(@ca1.id)
      concept2 = Concept.find(@ca2.id)

      assert_equal @ctl1.id, concept1.concept_scheme_id
      assert_equal @ctl1.id, concept2.concept_scheme_id
    end

    test 'concept without parent has correct concept_links' do
      assert_equal 0, ConceptLink.where(child_id: @ca1.id, link_type: 'broader').size
      assert_equal 1, ConceptLink.where(parent_id: @ca1.id, link_type: 'broader').size
      assert_equal 0, ConceptLink.where(child_id: @ca1.id, link_type: 'related').size
      assert_equal 0, ConceptLink.where(parent_id: @ca1.id, link_type: 'related').size
    end

    test 'concept with parent has correct concept_links' do
      assert_equal @ca1.id, ConceptLink.find_by(child_id: @ca2.id, link_type: 'broader').parent_id
      assert_equal 0, ConceptLink.where(parent_id: @ca2.id, link_type: 'broader').size
      assert_equal 0, ConceptLink.where(child_id: @ca2.id, link_type: 'related').size
      assert_equal 0, ConceptLink.where(parent_id: @ca2.id, link_type: 'related').size
    end

    test 'concept with parent has correct concept_links with mappings' do
      ctl2 = ClassificationTreeLabel.create(name: SecureRandom.hex(10))
      ca3 = create_classification(ctl2, SecureRandom.hex(10))
      ClassificationGroup.create(classification_id: @ca2.primary_classification.id, classification_alias_id: ca3.id)

      assert_equal ca3.id, ConceptLink.find_by(child_id: @ca2.id, link_type: 'related').parent_id
    end
  end
end
