# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Content
    module Attributes
      # End-to-end coverage of the override_or_mapped compute wired into a template (Redmine #47053):
      # a computed "effective" classification that is the manual override when set, otherwise the
      # target-tree concept mapped from the source classification (resolved via concept_links, so a
      # mapping hidden per #47172/#50677 still counts).
      class ComputedOverrideOrMappedTest < DataCycleCore::TestCases::ActiveSupportTestCase
        before(:all) do
          @tags = DataCycleCore::Concept.for_tree('Tags').with_name('Tag 1', 'Tag 2').index_by(&:name)
          @source_tree = DataCycleCore::ClassificationTreeLabel.create!(name: "OomSrc_#{SecureRandom.hex(6)}")
          @source_alias = @source_tree.create_classification_alias('MappedSource')
          @mapping = DataCycleCore::ClassificationGroup.create!(classification: @source_alias.primary_classification, classification_alias: @tags['Tag 1'].classification_alias)
        end

        # template_name is positional on purpose: every call site passes the data hash as a braceless
        # string-keyed hash, which Ruby would hand to a keyword parameter instead
        def create_content(data_hash, template_name = 'OverrideOrMapped-Place')
          DataCycleCore::TestPreparations.create_content(template_name:, data_hash: data_hash.merge('name' => 'Override Or Mapped Test'))
        end

        # effective_tag is computed with compute.after_save, i.e. inside the transaction of the save
        # that triggered it — so it is already stored when the save returns and no recompute has to
        # be simulated here.
        def effective_ids(content)
          Array.wrap(content.reload.get_data_hash['effective_tag'])
        end

        test 'without override the effective classification is the mapped target concept' do
          content = create_content('universal_classifications' => [@source_alias.primary_classification.id])

          assert_equal [@tags['Tag 1'].classification_id], effective_ids(content)
        end

        test 'the override wins over the mapped classification' do
          content = create_content(
            'universal_classifications' => [@source_alias.primary_classification.id],
            'override_tag' => [@tags['Tag 2'].classification_id]
          )

          assert_equal [@tags['Tag 2'].classification_id], effective_ids(content)
        end

        # the whole point of compute.after_save over compute.async: the value is committed by the
        # triggering save, so a reader right after it (the detail view behind the save-redirect)
        # already sees it instead of waiting for a cache_invalidation poll
        test 'the effective classification is stored by the save that triggers it' do
          content = create_content('universal_classifications' => [@source_alias.primary_classification.id])

          assert_includes content.after_save_computed_property_names, 'effective_tag'
          assert_equal [@tags['Tag 1'].classification_id], Array.wrap(content.get_data_hash['effective_tag'])
        end

        test 'a later save updates the effective classification without a recompute job' do
          content = create_content('universal_classifications' => [@source_alias.primary_classification.id])

          content.set_data_hash(data_hash: { 'override_tag' => [@tags['Tag 2'].classification_id] })

          assert_equal [@tags['Tag 2'].classification_id], effective_ids(content)
        end

        # compute.after_save is a standalone mode: a template that does not use it must not enter
        # the post-save recompute at all, so its save path stays exactly what it was.
        test 'an async compute never enters the after_save pass' do
          content = create_content(
            { 'universal_classifications' => [@source_alias.primary_classification.id] },
            'OverrideOrMappedAsync-Place'
          )

          assert_empty content.after_save_computed_property_names
          assert_includes content.async_computed_property_names, 'effective_tag'

          content.stub(:update_after_save_computed_values, ->(*) { flunk('compute.async must not use the after_save recompute') }) do
            content.set_data_hash(data_hash: { 'override_tag' => [@tags['Tag 2'].classification_id] })
          end

          content.update_computed_values(keys: ['effective_tag'])

          assert_equal [@tags['Tag 2'].classification_id], effective_ids(content)
        end

        test 'the mapped classification is resolved even when the target tree hides mappings (#50677)' do
          tags_tree = @tags['Tag 1'].classification_alias.classification_tree_label
          tags_tree.update!(hidden_mappings: true)

          content = create_content('universal_classifications' => [@source_alias.primary_classification.id])

          assert_equal [@tags['Tag 1'].classification_id], effective_ids(content)
        ensure
          tags_tree&.update!(hidden_mappings: false)
        end
      end
    end
  end
end
