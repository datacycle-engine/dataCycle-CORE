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
      @concept1 = @ca1.concept
      @ca2 = create_classification(@ctl1, SecureRandom.hex(10), SecureRandom.hex(20), @es_id, @ca1)
      @concept2 = @ca2.concept
    end

    test 'concept gets correct classification_id' do
      assert_equal @ca1.primary_classification.id, @concept1.classification_id
      assert_equal @ca2.primary_classification.id, @concept2.classification_id
    end

    test 'concept gets correct external_key' do
      assert_equal @ca1.primary_classification.external_key, @concept1.external_key
      assert_equal @ca2.primary_classification.external_key, @concept2.external_key
    end

    test 'concept gets correct classification_id with insert_all_classifications_by_path' do
      name = SecureRandom.hex(10)
      cs = ConceptScheme.find(@ctl1.id)
      cs.insert_all_classifications_by_path([{ path: [name] }])
      ca = ClassificationAlias.by_full_paths("#{@ctl1.name} > #{name}").first

      assert_equal ca.primary_classification.id, ca.concept.classification_id
    end

    test 'concept has correct concept_scheme_id' do
      assert_equal @ctl1.id, @concept1.concept_scheme_id
      assert_equal @ctl1.id, @concept2.concept_scheme_id
    end

    test 'concept without parent has correct concept_links' do
      assert_nil @concept1.parent
      assert_nil @concept1.parent_concept_link.parent_id
      assert_equal 1, @concept1.children.size
      assert_equal 0, @concept1.mapped_concepts.size
      assert_equal 0, @concept1.mapped_inverse_concepts.size
    end

    test 'concept with parent has correct concept_links' do
      assert_equal @ca1.id, @concept2.parent.id
      assert_equal 0, @concept2.children.size
      assert_equal 0, @concept2.mapped_concepts.size
      assert_equal 0, @concept2.mapped_inverse_concepts.size
    end

    test 'concept with parent has correct concept_links with mappings' do
      ctl2 = ClassificationTreeLabel.create(name: SecureRandom.hex(10))
      ca3 = create_classification(ctl2, SecureRandom.hex(10))
      ClassificationGroup.create(classification_id: @ca2.primary_classification.id, classification_alias_id: ca3.id)

      assert_equal @ca2.id, ca3.concept.mapped_concepts.first.id
      assert_equal ca3.id, @concept2.mapped_inverse_concepts.first.id
    end

    test 'create new concept_link with related' do
      concept1 = Concept.create(name: 'test', external_system_id: @es_id, internal: true, concept_scheme: @ctl1.concept_scheme)
      cl = ConceptLink.create(parent: @concept2, child: concept1, link_type: 'related')

      assert cl.is_a?(ConceptLink)
      assert_equal @concept2.id, cl.parent_id
      assert_equal concept1.id, cl.child_id
    end
  end
end
