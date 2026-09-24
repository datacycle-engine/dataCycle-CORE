# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'
require 'minitest/autorun'
require 'helpers/minitest_spec_helper'

describe DataCycleCore::Concept do
  include DataCycleCore::MinitestSpecHelper

  def concept_scheme
    @concept_scheme ||= DataCycleCore::ConceptScheme.create!(name: 'CLASSIFICATION TREE')
  end

  after do
    concept_scheme.reload.destroy
    @concept_scheme = nil
  end

  it 'should save translated concepts' do
    concept = concept_scheme.create_concept('CLASSIFICATION I', 'CLASSIFICATION I - A')

    I18n.with_locale(:en) do
      concept.name = 'English'
      concept.save!
    end

    assert_equal('CLASSIFICATION I - A', concept.name)
    I18n.with_locale(:en) { assert_equal('English', concept.name) }
    I18n.with_locale(:de) { assert_equal('CLASSIFICATION I - A', concept.name) }
    assert_equal('CLASSIFICATION I - A', concept.name)

    concept.name = 'Deutsch'
    concept.save!

    assert_equal('Deutsch', concept.name)
    assert_equal('Deutsch', concept.name)
  end

  it 'should fall back to an available locale if translations exist for unavailable locales' do
    concept = concept_scheme.create_concept('CLASSIFICATION I', 'Januar')
    I18n.with_locale(:cs) { concept.name = 'Leden' }
    concept.save!

    # :cs is translated but not part of I18n.available_locales, :en is available but untranslated
    [DataCycleCore::Concept, DataCycleCore::Concept].each do |model|
      content = model.find(concept.id)

      assert_equal([:cs, :de], content.translated_locales.sort)
      I18n.with_locale(:en) { assert_equal(:de, content.first_available_locale(['en'])) }
    end
  end

  it 'should fall back to a translated locale if none of them are available' do
    concept = concept_scheme.create_concept('CLASSIFICATION I', 'CLASSIFICATION I - A')
    concept.name = nil
    [:cs, :it].each { |locale| I18n.with_locale(locale) { concept.name = "CLASSIFICATION I - #{locale}" } }
    concept.save!

    [DataCycleCore::Concept, DataCycleCore::Concept].each do |model|
      content = model.find(concept.id)

      assert_equal([:cs, :it], content.translated_locales.sort)
      I18n.with_locale(:en) { assert_includes(content.translated_locales, content.first_available_locale(['en'])) }
    end
  end

  it 'should find concept in all languages' do
    concept = concept_scheme.create_concept('CLASSIFICATION I', "CLASSIFICATION I - A - #{I18n.locale}")
    locales = [:de, :en, :fr, :it]
    locales.each do |locale|
      I18n.with_locale(locale) { concept.name = "CLASSIFICATION I - A - #{I18n.locale}" }
    end
    concept.save!

    locales.each do |locale|
      I18n.with_locale(locale) do
        assert_equal(concept.name, DataCycleCore::Concept.find_by(name: "CLASSIFICATION I - A - #{I18n.locale}").name)
        assert_equal(concept.name, DataCycleCore::Concept.find_by_name("CLASSIFICATION I - A - #{I18n.locale}").name) # rubocop:disable Rails/DynamicFindBy
        assert_equal(concept.name, DataCycleCore::Concept.where(name: "CLASSIFICATION I - A - #{I18n.locale}").first.name)
        assert_equal(concept.name, DataCycleCore::Concept.where(name: "CLASSIFICATION I - A - #{I18n.locale}").pick(:name))
      end
    end
  end

  it 'should order concepts in all languages' do
    concept1 = concept_scheme.create_concept('CLASSIFICATION I', "CLASSIFICATION I - A - #{I18n.locale}")
    concept2 = concept_scheme.create_concept('CLASSIFICATION I', "CLASSIFICATION I - B - #{I18n.locale}")

    locales = [:en, :fr, :it]
    locales.each do |locale|
      I18n.with_locale(locale) { concept1.name = "CLASSIFICATION I - A - #{I18n.locale}" }
      I18n.with_locale(locale) { concept2.name = "CLASSIFICATION I - B - #{I18n.locale}" }
    end
    concept1.save!
    concept2.save!

    locales.each do |locale|
      I18n.with_locale(locale) do
        assert(DataCycleCore::Concept.for_tree('CLASSIFICATION TREE').with_name("CLASSIFICATION I - A - #{I18n.locale}").pick(:name), "CLASSIFICATION I - A - #{I18n.locale}")
        all_classifications = DataCycleCore::Concept.for_tree('CLASSIFICATION TREE').count

        assert_equal(all_classifications - 2, DataCycleCore::Concept.for_tree('CLASSIFICATION TREE').without_name("CLASSIFICATION I - A - #{I18n.locale}").count)

        concepts = [
          "CLASSIFICATION I - A - #{I18n.locale}",
          "CLASSIFICATION I - B - #{I18n.locale}"
        ]

        assert_equal(concepts.first, DataCycleCore::Concept.for_tree('CLASSIFICATION TREE').reorder(nil).order(name: :asc).pick(:name))
        assert_equal(concepts.last, DataCycleCore::Concept.for_tree('CLASSIFICATION TREE').where.not(name: nil).reorder(nil).order(name: :desc).pick(:name))
      end
    end
  end
end
