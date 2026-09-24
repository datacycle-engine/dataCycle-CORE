# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class TransitiveClassificationPathTest < DataCycleCore::TestCases::ActiveSupportTestCase
    before(:all) do
      @before_state = DataCycleCore.features[:transitive_classification_path][:enabled]
      DataCycleCore.features[:transitive_classification_path][:enabled] = true
      DataCycleCore::Feature::TransitiveClassificationPath.reload
      DataCycleCore::Feature::TransitiveClassificationPath.update_triggers(false)
      DataCycleCore::Feature::TransitiveClassificationPath.rebuild_transitive_tables!

      @content = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'TEST 1 ARTIKEL' })

      @tree2 = DataCycleCore::ConceptScheme.create!(name: 'Tree 2')
      @tree3 = DataCycleCore::ConceptScheme.create!(name: 'Tree 3')
      @tree2.create_concept('parent 1', 'mapped 1')
      @tree3.create_concept('parent 2', 'mapped 2')

      @parent1 = DataCycleCore::Concept.for_tree(@tree2.name).find_by!(internal_name: 'parent 1')
      @mapped1 = DataCycleCore::Concept.for_tree(@tree2.name).find_by!(internal_name: 'mapped 1')
      @parent2 = DataCycleCore::Concept.for_tree(@tree3.name).find_by!(internal_name: 'parent 2')
      @mapped2 = DataCycleCore::Concept.for_tree(@tree3.name).find_by!(internal_name: 'mapped 2')

      @parent1.update!(mapped_concept_ids: [@parent2.id])
      @mapped1.update!(mapped_concept_ids: [@mapped2.id])
    end

    after(:all) do
      DataCycleCore.features[:transitive_classification_path][:enabled] = @before_state
      DataCycleCore::Feature::TransitiveClassificationPath.reload
      DataCycleCore::Feature::TransitiveClassificationPath.update_triggers(false)
      DataCycleCore::Feature::TransitiveClassificationPath.rebuild_transitive_tables!
    end

    test 'collected_concept_contents link_type set correctly' do
      @content.concept_contents.create(concept_id: @mapped2.id, relation: 'dummy')
      ccc = @content.collected_concept_contents.where(relation: 'dummy')

      assert(ccc.any? { |cc| cc.concept_id == @mapped2.id && cc.link_type == 'direct' })
      assert(ccc.any? { |cc| cc.concept_id == @parent2.id && cc.link_type == 'broader' })
      assert(ccc.any? { |cc| cc.concept_id == @mapped1.id && cc.link_type == 'related' })

      # all mapping paths should be visible as related ccc
      assert(ccc.any? { |cc| cc.concept_id == @parent1.id && cc.link_type == 'related' })
    end
  end
end
