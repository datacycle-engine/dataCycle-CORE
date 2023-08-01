# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'
require 'minitest/autorun'
require 'helpers/minitest_spec_helper'

describe DataCycleCore::ClassificationAlias do
  include DataCycleCore::MinitestSpecHelper

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

  it 'should save translated classification_aliases' do
    classification_alias = classification_tree.create_classification_alias('CLASSIFICATION I', 'CLASSIFICATION I - A')

    I18n.with_locale(:en) do
      classification_alias.name = 'English'
      classification_alias.save!
    end

    assert(classification_alias.name, 'CLASSIFICATION I - A')
    I18n.with_locale(:en) { assert('English', classification_alias.name) }
    I18n.with_locale(:de) { assert('CLASSIFICATION I - A', classification_alias.name) }
    assert('CLASSIFICATION I - A', classification_alias.primary_classification.name)

    classification_alias.name = 'Deutsch'
    classification_alias.save!

    assert('Deutsch', classification_alias.name)
    assert('Deutsch', classification_alias.primary_classification.name)
  end

  it 'should find classification_alias in all languages' do
    classification_alias = classification_tree.create_classification_alias('CLASSIFICATION I', "CLASSIFICATION I - A - #{I18n.locale}")
    locales = [:de, :en, :fr, :it]
    locales.each do |locale|
      I18n.with_locale(locale) { classification_alias.name = "CLASSIFICATION I - A - #{I18n.locale}" }
    end
    classification_alias.save!

    locales.each do |locale|
      I18n.with_locale(locale) do
        assert(DataCycleCore::ClassificationAlias.find_by(name: "CLASSIFICATION I - A - #{I18n.locale}").name, classification_alias.name)
        assert(DataCycleCore::ClassificationAlias.find_by_name("CLASSIFICATION I - A - #{I18n.locale}").name, classification_alias.name) # rubocop:disable Rails/DynamicFindBy
        assert(DataCycleCore::ClassificationAlias.where(name: "CLASSIFICATION I - A - #{I18n.locale}").first.name, classification_alias.name)
        assert(DataCycleCore::ClassificationAlias.where(name: "CLASSIFICATION I - A - #{I18n.locale}").pick(:name), classification_alias.name)
      end
    end
  end

  it 'should order classification_aliases in all languages' do
    classification_alias1 = classification_tree.create_classification_alias('CLASSIFICATION I', "CLASSIFICATION I - A - #{I18n.locale}")
    classification_alias2 = classification_tree.create_classification_alias('CLASSIFICATION I', "CLASSIFICATION I - B - #{I18n.locale}")

    locales = [:en, :fr, :it]
    locales.each do |locale|
      I18n.with_locale(locale) { classification_alias1.name = "CLASSIFICATION I - A - #{I18n.locale}" }
      I18n.with_locale(locale) { classification_alias2.name = "CLASSIFICATION I - B - #{I18n.locale}" }
    end
    classification_alias1.save!
    classification_alias2.save!

    locales.each do |locale|
      I18n.with_locale(locale) do
        assert(DataCycleCore::ClassificationAlias.for_tree('CLASSIFICATION TREE').with_name("CLASSIFICATION I - A - #{I18n.locale}").pick(:name), "CLASSIFICATION I - A - #{I18n.locale}")
        all_classifications = DataCycleCore::ClassificationAlias.for_tree('CLASSIFICATION TREE').count
        assert(DataCycleCore::ClassificationAlias.for_tree('CLASSIFICATION TREE').without_name("CLASSIFICATION I - A - #{I18n.locale}").count, all_classifications - 2)

        classification_aliases = [
          "CLASSIFICATION I - A - #{I18n.locale}",
          "CLASSIFICATION I - B - #{I18n.locale}"
        ]
        assert(DataCycleCore::ClassificationAlias.for_tree('CLASSIFICATION TREE').reorder(nil).order(name: :asc).pick(:name), classification_aliases.first)
        assert(DataCycleCore::ClassificationAlias.for_tree('CLASSIFICATION TREE').where.not(name: nil).reorder(nil).order(name: :desc).pick(:name), classification_aliases.last)
      end
    end
  end
end
