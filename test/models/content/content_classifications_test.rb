# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'

module DataCycleCore
  module Content
    class ContentClassificationsTest < DataCycleCore::TestCases::ActiveSupportTestCase
      before(:all) do
        @content = DataCycleCore::TestPreparations.create_content(
          template_name: 'Artikel',
          data_hash: {
            name: 'TestArtikel',
            tags: DataCycleCore::Concept.for_tree('Tags').with_name('Tag 1').map(&:id)
          }
        )

        @concept_scheme = DataCycleCore::ConceptScheme.create(name: 'MAPPED TAGS')
        @mapped_tag = @concept_scheme.create_concept('MAPPED TAG 1')
        @mapped_tag.mapped_concepts << DataCycleCore::Concept.for_tree('Tags').with_name('Tag 1').to_a
      end

      test 'it should provide assigned classifications separately' do
        assert_not_empty(@content.concepts)
        assert_includes(@content.concepts.map(&:name), 'Tag 1')
        assert_not_includes(@content.concepts.map(&:name), 'MAPPED TAG 1')
      end

      test 'it should provide mapped classifications separately' do
        assert_not_empty(@content.mapped_concepts)
        assert_includes(@content.mapped_concepts.map(&:name), 'MAPPED TAG 1')
        assert_not_includes(@content.mapped_concepts.map(&:name), 'Tag 1')
      end

      test 'it should provide classifications for specific classification tree' do
        assert_empty(@content.concepts_for_tree(scheme_name: 'Unkown Tree'))

        assert_equal(1, @content.concepts_for_tree(scheme_name: 'Tags').size)
        assert_includes(@content.concepts_for_tree(scheme_name: 'Tags').map(&:name), 'Tag 1')

        assert_equal(1, @content.concepts_for_tree(scheme_name: 'Inhaltstypen').size)
        assert_includes(@content.concepts_for_tree(scheme_name: 'Inhaltstypen').map(&:name), 'Artikel')
      end
    end
  end
end
