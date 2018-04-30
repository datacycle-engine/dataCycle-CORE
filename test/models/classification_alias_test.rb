require 'test_helper'
require 'minitest/spec'
require 'minitest/autorun'

describe DataCycleCore::ClassificationAlias do
  def classification_tree
    @classification_tree ||= DataCycleCore::ClassificationTreeLabel.create!(name: 'CLASSIFICATION TREE')
  end

  after do
    classification_tree.tap(&:reload).classification_aliases.map(&:classifications).each(&:delete_all!)
    classification_tree.tap(&:reload).classification_aliases.map(&:classification_groups).each(&:delete_all!)
    classification_tree.tap(&:reload).classification_aliases.delete_all!
    classification_tree.tap(&:reload).classification_trees.delete_all!
    classification_tree.tap(&:reload).destroy_fully!
    @classification_tree = nil
  end

  it 'should pass on updated name to primary classification' do
    classification_alias = classification_tree.create_classification_alias('CLASSIFICATION I', 'CLASSIFICATION I - A')

    classification_alias.name = 'UPDATED NAME'
    classification_alias.save!

    classification_alias.name.must_equal 'UPDATED NAME'
    classification_alias.primary_classification.name.must_equal 'UPDATED NAME'
  end

  describe 'when searching' do
    before do
      classification_tree.create_classification_alias('A')
      classification_tree.create_classification_alias('A', 'A - 1')
      classification_tree.create_classification_alias('A', 'AB - 2')
      classification_tree.create_classification_alias('B')
      classification_tree.create_classification_alias('B', 'BCD - 1')
    end

    it 'should return matching classification aliases' do
      DataCycleCore::ClassificationAlias.for_tree('CLASSIFICATION TREE').search('A').count.must_equal 3
      DataCycleCore::ClassificationAlias.for_tree('CLASSIFICATION TREE').search('b').count.must_equal 3
      DataCycleCore::ClassificationAlias.for_tree('CLASSIFICATION TREE').search('1').count.must_equal 2
      DataCycleCore::ClassificationAlias.for_tree('CLASSIFICATION TREE').search('2').count.must_equal 1
    end
  end

  describe 'when including descendants' do
    before do
      classification_tree.create_classification_alias('A')
      classification_tree.create_classification_alias('A', 'A - 1')
      classification_tree.create_classification_alias('A', 'A - 2')
      classification_tree.create_classification_alias('A', 'A - 3')
      classification_tree.create_classification_alias('A', 'A - 3', 'A - 3 - a')
      classification_tree.create_classification_alias('A', 'A - 3', 'A - 3 - b')
      classification_tree.create_classification_alias('A', 'A - 3', 'A - 3 - c')
    end

    it 'should return correct number of classification aliases' do
      DataCycleCore::ClassificationAlias.for_tree('CLASSIFICATION TREE').with_name('A - 3')
        .with_descendants.count.must_equal 4
    end

    it 'should return classification aliases with correct name' do
      names = DataCycleCore::ClassificationAlias.for_tree('CLASSIFICATION TREE')
        .with_name('A - 3')
        .with_descendants
        .map(&:name)

      names.must_include 'A - 3'
      names.must_include 'A - 3 - a'
      names.must_include 'A - 3 - b'
      names.must_include 'A - 3 - c'
    end

    it 'should return classification aliases with correct paths' do
      paths = DataCycleCore::ClassificationAlias.for_tree('CLASSIFICATION TREE')
        .with_name('A - 3')
        .with_descendants
        .map(&:full_path)

      paths.must_include 'CLASSIFICATION TREE > A > A - 3'
      paths.must_include 'CLASSIFICATION TREE > A > A - 3 > A - 3 - a'
      paths.must_include 'CLASSIFICATION TREE > A > A - 3 > A - 3 - b'
      paths.must_include 'CLASSIFICATION TREE > A > A - 3 > A - 3 - c'
    end
  end

  describe 'when loading descendants' do
    before do
      classification_tree.create_classification_alias('A')
      classification_tree.create_classification_alias('A', 'A - 1')
      classification_tree.create_classification_alias('A', 'A - 2')
      classification_tree.create_classification_alias('A', 'A - 3')
      classification_tree.create_classification_alias('A', 'A - 3', 'A - 3 - a')
      classification_tree.create_classification_alias('A', 'A - 3', 'A - 3 - b')
      classification_tree.create_classification_alias('A', 'A - 3', 'A - 3 - c')
    end

    it 'should return correct number of descendants' do
      DataCycleCore::ClassificationAlias.for_tree('CLASSIFICATION TREE').with_name('A')
        .first.descendants.count.must_equal 6
      DataCycleCore::ClassificationAlias.for_tree('CLASSIFICATION TREE').with_name('A - 3')
        .first.descendants.count.must_equal 3
    end

    it 'should return descendants with correct name' do
      names = DataCycleCore::ClassificationAlias.for_tree('CLASSIFICATION TREE').with_name('A - 3')
        .first.descendants.map(&:name)

      names.wont_include 'A'
      names.wont_include 'A - 1'
      names.wont_include 'A - 2'
      names.wont_include 'A - 3'
      names.must_include 'A - 3 - a'
      names.must_include 'A - 3 - b'
      names.must_include 'A - 3 - c'
    end
  end
end
