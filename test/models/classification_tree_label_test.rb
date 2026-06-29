# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  # Renamed from ClassificationTreeLabelTest to avoid a superclass-mismatch collision with the
  # equally-named integration test (DataCycleCore::ClassificationTreeLabelTest) when parallel_tests
  # co-locates both files in one worker.
  class ClassificationTreeLabelModelTest < DataCycleCore::TestCases::ActiveSupportTestCase
    before(:all) do
      @label = DataCycleCore::ClassificationTreeLabel.create!(name: 'Coverage Tree Label')
      @deepest = @label.create_or_update_classification_alias_by_name('Coverage Root', { name: 'Coverage Child', external_key: 'CC-1' })
      @content = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'CTL Thing' })
    end

    test 'create_or_update_classification_alias_by_name creates then updates the hierarchy' do
      assert_equal('Coverage Child', @deepest.name)
      assert_equal('CC-1', @deepest.primary_classification.external_key)

      updated = @label.create_or_update_classification_alias_by_name('Coverage Root', { name: 'Coverage Child', external_key: 'CC-2' })

      assert_equal(@deepest.id, updated.id)
      assert_equal('CC-2', updated.reload.primary_classification.external_key)
    end

    test 'ancestors / to_api_default_values / to_hash' do
      assert_equal([], @label.ancestors)
      assert_equal('skos:ConceptScheme', @label.to_api_default_values['@type'])
      assert_equal(@label.id, @label.to_api_default_values['@id'])
      assert_equal('DataCycleCore::ClassificationTreeLabel', @label.to_hash['class_type'])
    end

    test 'to_select_option and self.to_select_options' do
      assert_kind_of(DataCycleCore::Filter::SelectOption, @label.to_select_option)
      assert_predicate(DataCycleCore::ClassificationTreeLabel.to_select_options, :present?)
    end

    test 'stored_filters returns a relation scoped by the tree id' do
      assert_kind_of(ActiveRecord::Relation, @label.stored_filters)
    end

    test 'sort_classifications_alphabetically! runs the ordering update' do
      assert_nothing_raised { @label.sort_classifications_alphabetically! }
    end

    test 'to_csv_for_mappings exports the classification paths' do
      assert_includes(@label.to_csv_for_mappings, 'Pfad zur Klassifizierung')
    end

    test 'to_csv_with_mappings and inverse export without error' do
      assert_includes(@label.to_csv_with_mappings, 'Pfad zur Klassifizierung')
      assert_includes(@label.to_csv_with_inverse_mappings, 'Pfad zur Klassifizierung')
    end

    test 'webhook helpers operate on the tree things' do
      contents = DataCycleCore::Thing.where(id: @content.id)

      @label.stub(:things, contents) do
        assert_nothing_raised do
          @label.send(:add_things_webhooks_job_update)
          @label.send(:execute_things_webhooks)
        end
      end
    end
  end
end
