# frozen_string_literal: true

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

  it 'should save translated classification_aliases' do
    classification_alias = classification_tree.create_classification_alias('CLASSIFICATION I', 'CLASSIFICATION I - A')

    I18n.with_locale(:en) do
      classification_alias.name = 'English'
      classification_alias.save!
    end

    classification_alias.name.must_equal 'CLASSIFICATION I - A'
    I18n.with_locale(:en) { classification_alias.name.must_equal 'English' }
    I18n.with_locale(:de) { classification_alias.name.must_equal 'CLASSIFICATION I - A' }
    classification_alias.primary_classification.name.must_equal 'CLASSIFICATION I - A'

    classification_alias.name = 'Deutsch'
    classification_alias.save!

    classification_alias.name.must_equal 'Deutsch'
    classification_alias.primary_classification.name.must_equal 'Deutsch'
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
        DataCycleCore::ClassificationAlias.find_by(name: "CLASSIFICATION I - A - #{I18n.locale}").name.must_equal classification_alias.name
        DataCycleCore::ClassificationAlias.find_by_name("CLASSIFICATION I - A - #{I18n.locale}").name.must_equal classification_alias.name # rubocop:disable Rails/DynamicFindBy
        DataCycleCore::ClassificationAlias.where(name: "CLASSIFICATION I - A - #{I18n.locale}").first.name.must_equal classification_alias.name
        DataCycleCore::ClassificationAlias.where(name: "CLASSIFICATION I - A - #{I18n.locale}").pluck(:name).first.must_equal classification_alias.name
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
        DataCycleCore::ClassificationAlias.for_tree('CLASSIFICATION TREE').with_name("CLASSIFICATION I - A - #{I18n.locale}").pluck(:name).first.must_equal "CLASSIFICATION I - A - #{I18n.locale}"
        all_classifications = DataCycleCore::ClassificationAlias.for_tree('CLASSIFICATION TREE').count
        DataCycleCore::ClassificationAlias.for_tree('CLASSIFICATION TREE').without_name("CLASSIFICATION I - A - #{I18n.locale}").count.must_equal all_classifications - 2

        classification_aliases = [
          "CLASSIFICATION I - A - #{I18n.locale}",
          "CLASSIFICATION I - B - #{I18n.locale}"
        ]
        DataCycleCore::ClassificationAlias.for_tree('CLASSIFICATION TREE').order(name: :asc).pluck(:name).first.must_equal classification_aliases.first
        DataCycleCore::ClassificationAlias.for_tree('CLASSIFICATION TREE').where.not(name: nil).order(name: :desc).pluck(:name).first.must_equal classification_aliases.last
      end
    end
  end
end
