# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class ConceptLinkTest < DataCycleCore::TestCases::ActiveSupportTestCase
    # a concept writes its own broader link in after_create, so the scheme and the parent are all
    # this needs
    def create_concept(concept_scheme, name, description = nil, external_system_id = nil, parent_concept = nil)
      Concept.create(name:, description:, external_system_id:, external_key: name, concept_scheme:, parent_concept:)
    end

    before(:all) do
      @es_id = ExternalSystem.first.id
      @ctl1 = ConceptScheme.create(name: SecureRandom.hex(10), external_system_id: @es_id)

      @concept1 = create_concept(@ctl1, SecureRandom.hex(10), SecureRandom.hex(20), @es_id)
      @concept2 = create_concept(@ctl1, SecureRandom.hex(10), SecureRandom.hex(20), @es_id, @concept1)
    end

    test 'insert_all_concepts_by_path places the concept under its scheme' do
      name = SecureRandom.hex(10)
      ConceptScheme.find(@ctl1.id).insert_all_concepts_by_path([{ path: [name] }])
      concept = Concept.by_full_paths("#{@ctl1.name} > #{name}").first

      assert_equal @ctl1.id, concept.concept_scheme_id
      assert_nil concept.parent_concept_link.parent_id
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
      assert_equal @concept1.id, @concept2.parent.id
      assert_equal 0, @concept2.children.size
      assert_equal 0, @concept2.mapped_concepts.size
      assert_equal 0, @concept2.mapped_inverse_concepts.size
    end

    test 'concept with parent has correct concept_links with mappings' do
      ctl2 = ConceptScheme.create(name: SecureRandom.hex(10))
      concept3 = create_concept(ctl2, SecureRandom.hex(10))
      ConceptLink.create(parent: concept3, child: @concept2, link_type: ConceptLink::LINK_TYPE_RELATED)

      assert_equal @concept2.id, concept3.mapped_concepts.first.id
      assert_equal concept3.id, @concept2.mapped_inverse_concepts.first.id
    end

    test 'create new concept_link with related' do
      concept1 = Concept.create(name: 'test', external_system_id: @es_id, internal: true, concept_scheme: @ctl1)
      cl = ConceptLink.create(parent: @concept2, child: concept1, link_type: 'related')

      assert cl.is_a?(ConceptLink)
      assert_equal @concept2.id, cl.parent_id
      assert_equal concept1.id, cl.child_id
    end

    test 'create with an array maps over each entry' do
      concept = Concept.create(name: SecureRandom.hex(10), external_system_id: @es_id, internal: true, concept_scheme: @ctl1)
      results = ConceptLink.create([{ parent: @concept2, child: concept, link_type: 'related' }])

      assert_kind_of Array, results
      assert_equal 1, results.size
      assert results.first.is_a?(ConceptLink)
    end

    test 'a moved concept keeps its single broader link' do
      parent = create_concept(@ctl1, SecureRandom.hex(10), nil, @es_id)
      child = create_concept(@ctl1, SecureRandom.hex(10), nil, @es_id)

      child.parent_concept_link.update!(parent_id: parent.id)

      assert_equal 1, ConceptLink.broader.where(child_id: child.id).count
      assert_equal parent.id, child.reload.parent.id
    end

    test 'insert_all writes the mappings the bulk import upserts' do
      first_parent = create_concept(@ctl1, SecureRandom.hex(10), nil, @es_id)
      second_parent = create_concept(@ctl1, SecureRandom.hex(10), nil, @es_id)

      result = ConceptLink.insert_all(
        [
          { link_type: ConceptLink::LINK_TYPE_RELATED, parent_id: first_parent.id, child_id: @concept1.id },
          { link_type: ConceptLink::LINK_TYPE_RELATED, parent_id: second_parent.id, child_id: @concept1.id }
        ],
        returning: :id,
        unique_by: :index_concept_links_on_parent_id_and_child_id
      )

      assert_equal 2, result.rows.size
    end

    # index_concept_links_on_child_id is partial on 'broader', which is what makes "every concept
    # has exactly one broader link" hold: concept_paths and update_concepts_order_a both walk from
    # the link whose parent_id is NULL, and a second one would fork that walk.
    test 'a concept cannot hold a second broader link' do
      other_parent = create_concept(@ctl1, SecureRandom.hex(10), nil, @es_id)

      assert_raises ActiveRecord::RecordNotUnique do
        ConceptLink.create!(parent: other_parent, child: @concept2, link_type: ConceptLink::LINK_TYPE_BROADER)
      end
    end
  end
end
