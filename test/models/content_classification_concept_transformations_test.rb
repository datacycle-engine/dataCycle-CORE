# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class ContentClassificationConceptTransformationsTest < DataCycleCore::TestCases::ActiveSupportTestCase
    before(:all) do
      @tags = DataCycleCore::ClassificationTreeLabel.find_or_create_by!(name: 'Tags')
      @tags.create_classification_alias('child 1')
      @tag1 = DataCycleCore::Concept.for_tree(@tags.name).find_by!(internal_name: 'child 1')

      @tags2 = DataCycleCore::ClassificationTreeLabel.find_or_create_by!(name: 'Tags2')
      @tags2.create_classification_alias('child 2')
      @tag2 = DataCycleCore::Concept.for_tree(@tags2.name).find_by!(internal_name: 'child 2')

      @tags3 = DataCycleCore::ClassificationTreeLabel.find_or_create_by!(name: 'Tags3')
      @tags3.create_classification_alias('child 3')
      @tag3 = DataCycleCore::Concept.for_tree(@tags3.name).find_by!(internal_name: 'child 3')

      @universal_tags = DataCycleCore::ClassificationTreeLabel.find_or_create_by!(name: 'Universal Tags')
      @universal_tags.create_classification_alias('uv 1')
      @uv1 = DataCycleCore::Concept.for_tree(@universal_tags.name).find_by!(internal_name: 'uv 1')

      @dummy_tree = DataCycleCore::ClassificationTreeLabel.find_or_create_by!(name: 'DummyTree')
      @dummy_tree.create_classification_alias('dummy 1')
      @dummy1 = DataCycleCore::Concept.for_tree(@dummy_tree.name).find_by!(internal_name: 'dummy 1')

      @tag1.classification_alias.classification_ids += [@dummy1.classification_id]
      @uv1.classification_alias.classification_ids += [@dummy1.classification_id]

      @universal = [@dummy1.classification_id, @tag2.classification_id, @tag3.classification_id]

      @article = DataCycleCore::TestPreparations.create_content(
        template_name: 'Artikel',
        data_hash: {
          name: 'Test Article 1',
          universal_classifications: @universal
        }
      )
    end

    test 'move mapped classifications for Tags to corresponding key' do
      valid = @article.mapped_concepts_to_property(concept_scheme: @tags)

      assert(valid)
      assert_equal([@tag1.classification_id], @article.tags.pluck(:id))
      assert_equal(@universal.to_set, @article.universal_classifications.pluck(:id).to_set)
      assert_equal(
        I18n.t('concept_scheme_link.version_name', data: @tags.name, locale: I18n.default_locale),
        @article.version_name
      )
    end

    test 'move mapped classifications for Universal Tags to corresponding key' do
      valid = @article.mapped_concepts_to_property(concept_scheme: @universal_tags)

      assert(valid)
      assert_equal([], @article.tags.pluck(:id))
      assert_equal([*@universal, @uv1.classification_id].to_set, @article.universal_classifications.pluck(:id).to_set)
      assert_equal(
        I18n.t('concept_scheme_link.version_name', data: @universal_tags.name, locale: I18n.default_locale),
        @article.version_name
      )
    end

    test 'move nothing for nil concept_scheme' do
      valid = @article.mapped_concepts_to_property(concept_scheme: nil)

      assert_nil(valid)
      assert_equal([], @article.tags.pluck(:id))
      assert_equal(@universal.to_set, @article.universal_classifications.pluck(:id).to_set)
    end

    test 'move nothing for already assigned concept_scheme' do
      valid = @article.mapped_concepts_to_property(concept_scheme: @tags2)

      assert_nil(valid)
      assert_equal([], @article.tags.pluck(:id))
      assert_equal(@universal.to_set, @article.universal_classifications.pluck(:id).to_set)
    end

    test 'remove classifications for assigned dummy tree' do
      valid = @article.remove_concepts_by_scheme(concept_scheme: @dummy_tree)

      assert(valid)
      assert_equal((@universal - [@dummy1.classification_id]).to_set, @article.universal_classifications.pluck(:id).to_set)
      assert_equal(
        I18n.t('concept_scheme_unlink.version_name', data: @dummy_tree.name, locale: I18n.default_locale),
        @article.version_name
      )
    end

    test 'remove classifications for assigned tags tree' do
      valid = @article.mapped_concepts_to_property(concept_scheme: @tags)
      assert(valid)

      valid = @article.remove_concepts_by_scheme(concept_scheme: @tags)
      assert(valid)
      assert_equal(@universal.to_set, @article.universal_classifications.pluck(:id).to_set)
      assert_empty(@article.tags.pluck(:id))
      assert_equal(
        I18n.t('concept_scheme_unlink.version_name', data: @tags.name, locale: I18n.default_locale),
        @article.version_name
      )
    end

    test 'remove classifications for unassigned tree' do
      valid = @article.remove_concepts_by_scheme(concept_scheme: @tags)
      assert_nil(valid)
      assert_equal(@universal.to_set, @article.universal_classifications.pluck(:id).to_set)
      assert_empty(@article.tags.pluck(:id))
      assert_nil(@article.version_name)
    end
  end
end
