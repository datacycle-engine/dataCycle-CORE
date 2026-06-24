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

      @tree2 = DataCycleCore::ClassificationTreeLabel.create!(name: 'Tree 2')
      @tree3 = DataCycleCore::ClassificationTreeLabel.create!(name: 'Tree 3')
      @tree2.create_classification_alias('parent 1', 'mapped 1')
      @tree3.create_classification_alias('parent 2', 'mapped 2')

      @parent1 = DataCycleCore::ClassificationAlias.for_tree(@tree2.name).find_by!(internal_name: 'parent 1')
      @mapped1 = DataCycleCore::ClassificationAlias.for_tree(@tree2.name).find_by!(internal_name: 'mapped 1')
      @parent2 = DataCycleCore::ClassificationAlias.for_tree(@tree3.name).find_by!(internal_name: 'parent 2')
      @mapped2 = DataCycleCore::ClassificationAlias.for_tree(@tree3.name).find_by!(internal_name: 'mapped 2')

      @parent1.update!(classification_ids: [@parent1.primary_classification.id, @parent2.primary_classification.id])
      @mapped1.update!(classification_ids: [@mapped1.primary_classification.id, @mapped2.primary_classification.id])
    end

    after(:all) do
      DataCycleCore.features[:transitive_classification_path][:enabled] = @before_state
      DataCycleCore::Feature::TransitiveClassificationPath.reload
      DataCycleCore::Feature::TransitiveClassificationPath.update_triggers(false)
      DataCycleCore::Feature::TransitiveClassificationPath.rebuild_transitive_tables!
    end

    test 'collected_classification_contents link_type set correctly' do
      @content.classification_contents.create(classification_id: @mapped2.primary_classification.id, relation: 'dummy')
      ccc = @content.collected_classification_contents.where(relation: 'dummy')

      assert(ccc.any? { |cc| cc.classification_alias_id == @mapped2.id && cc.link_type == 'direct' })
      assert(ccc.any? { |cc| cc.classification_alias_id == @parent2.id && cc.link_type == 'broader' })
      assert(ccc.any? { |cc| cc.classification_alias_id == @mapped1.id && cc.link_type == 'related' })

      # all mapping paths should be visible as related ccc
      assert(ccc.any? { |cc| cc.classification_alias_id == @parent1.id && cc.link_type == 'related' })
    end
  end
end
