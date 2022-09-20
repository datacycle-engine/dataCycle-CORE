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

    test 'destroy classification_tree_label with mappings' do
      @classification_tree_label.destroy

      assert @classification1.reload.destroyed?
      assert @classification_alias1.reload.destroyed?
      assert @classification_group1.reload.destroyed?
      assert @classification2.reload.destroyed?
      assert @classification_alias2.reload.destroyed?
      assert @classification_group2.reload.destroyed?
    end

    test 'destroy single classification_alias' do
      @classification_alias1.destroy

      assert @classification1.reload.destroyed?
      assert @classification_alias1.reload.destroyed?
      assert @classification_group1.reload.destroyed?
    end

    test 'destroy multiple classification_aliases' do
      DataCycleCore::ClassificationAlias.for_tree(@classification_tree_label.name).destroy_all

      assert @classification1.reload.destroyed?
      assert @classification_alias1.reload.destroyed?
      assert @classification_group1.reload.destroyed?
      assert @classification2.reload.destroyed?
      assert @classification_alias2.reload.destroyed?
      assert @classification_group2.reload.destroyed?
    end

    test 'create mapping with create_mapping_for_path' do
      assert_equal [@classification1.id].to_set, @classification_alias1.reload.classification_ids.to_set

      @classification_alias1.create_mapping_for_path(@classification_alias2.full_path)

      assert_equal [@classification1.id, @classification2.id].to_set, @classification_alias1.reload.classification_ids.to_set
    end

    test 'custom_find_by_full_path' do
      assert_equal @classification_alias1.id, DataCycleCore::ClassificationAlias.custom_find_by_full_path(@classification_alias1.full_path)&.id
      assert_equal @classification_alias1.id, DataCycleCore::ClassificationAlias.custom_find_by_full_path!(@classification_alias1.full_path)&.id

      assert_nil DataCycleCore::ClassificationAlias.custom_find_by_full_path('NON > Existant > Path')

      assert_raises ActiveRecord::RecordNotFound do
        DataCycleCore::ClassificationAlias.custom_find_by_full_path!('NON > Existant > Path')
      end
    end
  end
end
