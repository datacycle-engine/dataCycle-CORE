# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class ImportClassificationsTest < DataCycleCore::TestCases::ActiveSupportTestCase
    DummyUtilityObject = Struct.new(:external_source, :options)

    before(:all) do
      @subject = DataCycleCore::Generic::Common::ImportFunctions
      @local_system = DataCycleCore::ExternalSystem.find_by(identifier: 'local-system')
      @utility_object = DummyUtilityObject.new(@local_system, {})
    end

    test 'import_classification creates classification, alias, group and tree' do
      classification_alias = @subject.import_classification(
        utility_object: @utility_object,
        classification_data: { name: 'IC One', external_key: 'ic-1', tree_name: 'IC Tree' }
      )

      assert_predicate(classification_alias, :persisted?)
      assert_equal('IC One', classification_alias.name)
      assert_equal('ic-1', classification_alias.external_key)
      assert_equal(@local_system.id, classification_alias.external_source_id)

      classification = DataCycleCore::Classification.find_by(external_key: 'ic-1', external_source_id: @local_system.id)

      assert_not_nil(classification)
      assert_equal('IC One', classification.name)
      assert_equal([classification.id], classification_alias.classifications.pluck(:id))

      tree_label = DataCycleCore::ClassificationTreeLabel.find_by(name: 'IC Tree', external_source_id: @local_system.id)

      assert_not_nil(tree_label)
      assert_equal('IC Tree', tree_label.external_key)

      classification_tree = DataCycleCore::ClassificationTree.find_by(classification_alias_id: classification_alias.id)

      assert_equal(tree_label.id, classification_tree.classification_tree_label_id)
      assert_nil(classification_tree.parent_classification_alias_id)
    end

    test 'import_classification attaches children to their parent alias' do
      parent_alias = @subject.import_classification(
        utility_object: @utility_object,
        classification_data: { name: 'IC Parent', external_key: 'ic-parent', tree_name: 'IC Hierarchy Tree' }
      )
      child_alias = @subject.import_classification(
        utility_object: @utility_object,
        classification_data: { name: 'IC Child', external_key: 'ic-child', tree_name: 'IC Hierarchy Tree' },
        parent_classification_alias: parent_alias
      )
      classification_tree = DataCycleCore::ClassificationTree.find_by(classification_alias_id: child_alias.id)

      assert_equal(parent_alias.id, classification_tree.parent_classification_alias_id)
    end

    test 'import_classification updates existing classifications by external key' do
      @subject.import_classification(
        utility_object: @utility_object,
        classification_data: { name: 'IC Original', external_key: 'ic-update', tree_name: 'IC Update Tree' }
      )
      updated_alias = @subject.import_classification(
        utility_object: @utility_object,
        classification_data: { name: 'IC Renamed', external_key: 'ic-update', tree_name: 'IC Update Tree', description: 'New Description', uri: 'https://uri.test/ic' }
      )

      assert_equal('IC Renamed', updated_alias.name)
      assert_equal('New Description', updated_alias.description)
      assert_equal('https://uri.test/ic', updated_alias.uri)

      classification = DataCycleCore::Classification.find_by(external_key: 'ic-update', external_source_id: @local_system.id)

      assert_equal('IC Renamed', classification.name)
      assert_equal('New Description', classification.description)
      assert_equal('https://uri.test/ic', classification.uri)
      assert_equal(1, DataCycleCore::Concept.for_tree('IC Update Tree').count)
    end

    test 'import_classification returns nil for blank names' do
      assert_nil(
        @subject.import_classification(
          utility_object: @utility_object,
          classification_data: { name: '', external_key: 'ic-blank', tree_name: 'IC Tree' }
        )
      )
      assert_nil(DataCycleCore::Classification.find_by(external_key: 'ic-blank', external_source_id: @local_system.id))
    end

    test 'import_classification finds classifications by name without external key' do
      classification_alias = @subject.import_classification(
        utility_object: @utility_object,
        classification_data: { name: 'IC No Key', tree_name: 'IC NoKey Tree' }
      )

      assert_predicate(classification_alias, :persisted?)
      assert_nil(classification_alias.external_key)
      assert_not_nil(DataCycleCore::Classification.find_by(name: 'IC No Key', external_source_id: @local_system.id))
    end

    test 'import_classification supports no_external_source_id option' do
      utility_object = DummyUtilityObject.new(@local_system, { 'import' => { 'no_external_source_id' => true } })
      classification_alias = @subject.import_classification(
        utility_object:,
        classification_data: { name: 'IC Without Source', external_key: 'ic-no-source', tree_name: 'IC NoSource Tree' }
      )

      assert_nil(classification_alias.external_source_id)
      assert_not_nil(DataCycleCore::Classification.find_by(external_key: 'ic-no-source', external_source_id: nil))
    end

    test 'import_classifications_frame calls the processing function per locale with merged options' do
      import_object = DataCycleCore::Generic::ImportObject.new(
        external_source: @local_system,
        locales: [:de],
        import: {
          import_strategy: 'DataCycleCore::Generic::Common::ImportContents',
          source_type: 'things',
          name: 'frame_step'
        }
      )
      calls = []
      classification_processing = lambda do |mongo_item, logging, utility_object, locale, tree_name, options|
        calls << { mongo_item:, logging:, utility_object:, locale:, tree_name:, options: }
      end

      @subject.import_classifications_frame(import_object, 'IC Frame Tree', classification_processing, { import: { name: 'frame_import' } })

      assert_equal(1, calls.size)
      assert_equal(:de, calls.first[:locale])
      assert_equal('IC Frame Tree', calls.first[:tree_name])
      assert_equal(import_object, calls.first[:utility_object])
      assert_equal('frame_import', calls.first[:options][:importer_name])
      assert_equal('things', calls.first[:options][:phase_name].to_s)
      assert_not_nil(calls.first[:mongo_item])
      assert_not_nil(calls.first[:logging])
    end
  end
end
