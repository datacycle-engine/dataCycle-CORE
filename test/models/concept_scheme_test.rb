# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class ConceptSchemeTest < DataCycleCore::TestCases::ActiveSupportTestCase
    before(:all) do
      @es_id = ExternalSystem.first.id
      @ctl = ClassificationTreeLabel.create(name: SecureRandom.hex(10), external_source_id: @es_id)
    end

    test 'concept_scheme gets created from classification_tree_label' do
      concept_scheme = ConceptScheme.find(@ctl.id)

      assert_equal @ctl.name, concept_scheme.name
      assert_equal @ctl.external_source_id, concept_scheme.external_system_id
    end

    test 'concept_scheme gets updated from classification_tree_label' do
      @ctl.update(name: SecureRandom.hex(10))
      concept_scheme = ConceptScheme.find(@ctl.id)

      assert_equal @ctl.name, concept_scheme.name
    end

    test 'concept_scheme gets delete when classification_tree_label is soft deleted' do
      @ctl.destroy

      assert_raise(ActiveRecord::RecordNotFound) do
        ConceptScheme.find(@ctl.id)
      end
    end

    test 'concept_scheme gets delete when classification_tree_label is really deleted' do
      @ctl.destroy_fully!

      assert_raise(ActiveRecord::RecordNotFound) do
        ConceptScheme.find(@ctl.id)
      end
    end
  end
end
