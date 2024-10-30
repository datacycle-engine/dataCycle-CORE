# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class ClassificationAliasMoveAfterTest < DataCycleCore::TestCases::ActiveSupportTestCase
    before(:all) do
      @tree_label1 = DataCycleCore::ClassificationTreeLabel.create!(name: 'CLASSIFICATION TREE 1')
      @tree_label2 = DataCycleCore::ClassificationTreeLabel.create!(name: 'CLASSIFICATION TREE 2')

      [@tree_label1, @tree_label2].each.with_index do |tree_label, index|
        instance_variable_set(:"@alias#{index}0", tree_label.create_classification_alias('A'))
        instance_variable_set(:"@alias#{index}1", tree_label.create_classification_alias('A', '1'))
        instance_variable_set(:"@alias#{index}2", tree_label.create_classification_alias('A', '2'))
        instance_variable_set(:"@alias#{index}3", tree_label.create_classification_alias('A', '3'))
        instance_variable_set(:"@alias#{index}4", tree_label.create_classification_alias('A', '3', '11'))
        instance_variable_set(:"@alias#{index}5", tree_label.create_classification_alias('A', '3', '22'))
        instance_variable_set(:"@alias#{index}6", tree_label.create_classification_alias('A', '3', '33'))

        instance_variable_set(:"@alias#{index}7", tree_label.create_classification_alias('B'))
        instance_variable_set(:"@alias#{index}8", tree_label.create_classification_alias('B', '1'))
        instance_variable_set(:"@alias#{index}9", tree_label.create_classification_alias('B', '2'))
        instance_variable_set(:"@alias#{index}10", tree_label.create_classification_alias('B', '3'))
        instance_variable_set(:"@alias#{index}11", tree_label.create_classification_alias('B', '3', '11'))
        instance_variable_set(:"@alias#{index}12", tree_label.create_classification_alias('B', '3', '22'))
        instance_variable_set(:"@alias#{index}13", tree_label.create_classification_alias('B', '3', '33'))
      end
    end

    test 'move_after on single level without parent_classification_alias' do
      assert_equal 1, @alias00.order_a
      assert_equal 8, @alias07.order_a

      @alias00.move_after(@tree_label1, @alias07)

      assert_equal 8, @alias00.reload.order_a
      assert_equal 1, @alias07.reload.order_a

      @alias00.move_after(@tree_label1, nil)

      assert_equal 1, @alias00.reload.order_a
      assert_equal 8, @alias07.reload.order_a
    end

    test 'move_after on single level with parent_classification_alias' do
      assert_equal 2, @alias01.order_a
      assert_equal 3, @alias02.order_a
      assert_equal 4, @alias03.order_a

      @alias01.move_after(@tree_label1, @alias02)

      assert_equal 3, @alias01.reload.order_a
      assert_equal 2, @alias02.reload.order_a

      @alias01.move_after(@tree_label1, @alias03)

      assert_equal 7, @alias01.reload.order_a
      assert_equal 2, @alias02.reload.order_a
      assert_equal 3, @alias03.reload.order_a

      @alias01.move_after(@tree_label1, nil, @alias00)

      assert_equal 2, @alias01.reload.order_a
      assert_equal 3, @alias02.reload.order_a
      assert_equal 4, @alias03.reload.order_a
    end

    test 'move_after between levels' do
      assert_equal 2, @alias01.order_a
      assert_equal 5, @alias04.order_a

      @alias01.move_after(@tree_label1, nil, @alias03)

      assert_equal 4, @alias01.reload.order_a
      assert_equal 5, @alias04.reload.order_a

      @alias01.move_after(@tree_label1, nil, @alias00)

      assert_equal 2, @alias01.reload.order_a

      @alias01.move_after(@tree_label1, @alias04)

      assert_equal 5, @alias01.reload.order_a
      assert_equal 4, @alias04.reload.order_a

      @alias01.move_after(@tree_label1, @alias06)

      assert_equal 7, @alias01.reload.order_a
      assert_equal 4, @alias04.reload.order_a
      assert_equal 5, @alias05.reload.order_a
      assert_equal 6, @alias06.reload.order_a
    end

    test 'move_after between trees' do
      assert_equal 1, @alias00.order_a
      assert_equal 1, @alias10.order_a

      @alias00.move_after(@tree_label2, nil)

      assert_equal 1, @alias00.reload.order_a
      assert_equal 8, @alias10.reload.order_a
      assert_equal 9, @alias11.reload.order_a
      assert_equal 8, @alias07.reload.order_a

      @alias00.move_after(@tree_label1, nil, @alias09)

      assert_equal 8, @alias10.reload.order_a
      assert_equal 4, @alias00.reload.order_a
      assert_equal 5, @alias01.reload.order_a

      @alias012.move_after(@tree_label2, @alias112)

      assert_equal 14, @alias012.reload.order_a
      assert_equal 13, @alias112.reload.order_a
    end
  end
end
