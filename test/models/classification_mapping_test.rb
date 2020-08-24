# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class ClassificationMappingTest < ActiveSupport::TestCase
    def setup
      @classification_tree_label = DataCycleCore::ClassificationTreeLabel.create!(name: 'Test Label 1')
      @classification_alias1 = DataCycleCore::ClassificationAlias.create!(name: 'Test Alias 1')
      @classification1 = DataCycleCore::Classification.create!(name: 'Test Classificaion 1')
      @classification_group1 = DataCycleCore::ClassificationGroup.create!(
        classification: @classification1,
        classification_alias: @classification_alias1
      )
      @classification_tree1 = DataCycleCore::ClassificationTree.create!({
        classification_tree_label: @classification_tree_label,
        parent_classification_alias: nil,
        sub_classification_alias: @classification_alias1
      })
      @classification_alias2 = DataCycleCore::ClassificationAlias.create!(name: 'Test Alias 2')
      @classification2 = DataCycleCore::Classification.create!(name: 'Test Classificaion 2')
      @classification_group2 = DataCycleCore::ClassificationGroup.create!(
        classification: @classification2,
        classification_alias: @classification_alias2
      )
      @classification_tree2 = DataCycleCore::ClassificationTree.create!({
        classification_tree_label: @classification_tree_label,
        parent_classification_alias: nil,
        sub_classification_alias: @classification_alias2
      })
    end

    test 'destroy classification including aliases and groups' do
      @classification_tree1.destroy

      assert @classification1.reload.destroyed?
      assert @classification_alias1.reload.destroyed?
      assert @classification_group1.reload.destroyed?
      assert_not @classification2.reload.destroyed?
      assert_not @classification_alias2.reload.destroyed?
      assert_not @classification_group2.reload.destroyed?
    end

    test 'destroy classification with mappings including aliases and groups' do
      @classification_alias1.update(classification_ids: [@classification1.id, @classification2.id])
      @classification_tree1.destroy

      assert @classification1.reload.destroyed?
      assert @classification_alias1.reload.destroyed?
      assert @classification_group1.reload.destroyed?
      assert_not @classification2.reload.destroyed?
      assert_not @classification_alias2.reload.destroyed?
      assert_not @classification_group2.reload.destroyed?
    end

    test 'destroy classification with mappings from another alias including aliases and groups' do
      @classification_alias2.update(classification_ids: [@classification1.id, @classification2.id])
      @classification_tree1.destroy

      assert @classification1.reload.destroyed?
      assert @classification_alias1.reload.destroyed?
      assert @classification_group1.reload.destroyed?
      assert_not @classification2.reload.destroyed?
      assert_not @classification_alias2.reload.destroyed?
      assert_not @classification_group2.reload.destroyed?
    end
  end
end
