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

    test 'import_classifications imports root classifications and their children' do
      load_root = ->(_mongo_item, locale, _options) { [{ 'dump' => { locale => { 'id' => 'icp-root', 'name' => 'ICP Root', 'key' => 'icp-root' } } }] }
      load_child = lambda do |_mongo_item, raw, locale|
        raw['key'] == 'icp-root' ? [{ 'dump' => { locale => { 'id' => 'icp-child', 'name' => 'ICP Child', 'key' => 'icp-child' } } }] : []
      end
      load_parent = ->(_raw, _external_source_id, _options) {}
      extract = ->(_options, raw) { { name: raw['name'], external_key: raw['key'] } }

      @subject.import_classifications(pipeline_import_object('icp_step'), 'ICP Tree', load_root, load_child, load_parent, extract, { import: {} })

      assert_not_nil(DataCycleCore::Classification.find_by(external_key: 'icp-root', external_source_id: @local_system.id))
      assert_not_nil(DataCycleCore::Classification.find_by(external_key: 'icp-child', external_source_id: @local_system.id))
    end

    test 'import_classifications_with_filter enables filters, locale-aware extraction and respects max_count' do
      load_root = ->(_mongo_item, _locale, _options, _source_filter) { [{ 'dump' => { de: { 'name' => 'WF Root', 'key' => 'wf-root' } } }] }
      load_child = ->(_mongo_item, _raw, _locale, _source_filter) { [] }
      load_parent = ->(_raw, _external_source_id, _options) {}
      extract = ->(_options, raw, locale:) { { name: "#{raw['name']} #{locale}", external_key: raw['key'] } }
      options = { import: { source_filter: { 'foo' => 'bar' } }, max_count: 1 }

      @subject.import_classifications_with_filter(pipeline_import_object('wf_step'), 'WF Tree', load_root, load_child, load_parent, extract, options)

      assert_not_nil(DataCycleCore::Classification.find_by(external_key: 'wf-root', external_source_id: @local_system.id))
    end

    test 'import_classifications supports filter_object iterators' do
      # keyword names must stay literal: filter_object? detects a param named :filter_object
      load_root = ->(filter_object:, options:) { [{ 'dump' => { de: { 'name' => 'FO Root', 'key' => 'fo-root' } } }] } # rubocop:disable Lint/UnusedBlockArgument
      load_child = ->(filter_object:, data:, options:) { [] } # rubocop:disable Lint/UnusedBlockArgument
      load_parent = ->(_raw, _external_source_id, _options) {}
      extract = ->(_options, raw) { { name: raw['name'], external_key: raw['key'] } }

      @subject.import_classifications(pipeline_import_object('fo_step'), 'FO Tree', load_root, load_child, load_parent, extract, { import: {} })

      assert_not_nil(DataCycleCore::Classification.find_by(external_key: 'fo-root', external_source_id: @local_system.id))
    end

    test 'import_classifications skips items below min_count' do
      load_root = ->(_mongo_item, locale, _options) { [{ 'dump' => { locale => { 'name' => 'Skipped', 'key' => 'mc-skip' } } }] }
      load_child = ->(_mongo_item, _raw, _locale) { [] }
      load_parent = ->(_raw, _external_source_id, _options) {}
      extract = ->(_options, raw) { { name: raw['name'], external_key: raw['key'] } }

      @subject.import_classifications(pipeline_import_object('mc_step'), 'MC Tree', load_root, load_child, load_parent, extract, { import: {}, min_count: 5 })

      assert_nil(DataCycleCore::Classification.find_by(external_key: 'mc-skip', external_source_id: @local_system.id))
    end

    test 'import_classifications rescues per-item errors and fails the phase' do
      load_root = ->(_mongo_item, locale, _options) { [{ 'dump' => { locale => { 'id' => 'err-id', 'name' => 'Boom', 'key' => 'err-key' } } }] }
      load_child = ->(_mongo_item, _raw, _locale) { [] }
      load_parent = ->(_raw, _external_source_id, _options) {}
      extract = ->(_options, _raw) { raise 'boom' }

      ActiveSupport::Notifications.stub(:instrument, ->(*_args, **_kwargs, &block) { block&.call }) do
        assert_nothing_raised do
          @subject.import_classifications(pipeline_import_object('err_step'), 'ERR Tree', load_root, load_child, load_parent, extract, { import: {} })
        end
      end

      assert_nil(DataCycleCore::Classification.find_by(external_key: 'err-key', external_source_id: @local_system.id))
    end

    test 'import_classifications2 imports parents with their extracted children' do
      load_root = ->(_mongo_item, locale, _options) { [{ 'dump' => { locale => { 'name' => 'IC2 Parent', 'key' => 'ic2-parent' } } }] }
      load_parent = ->(_data, _external_source_id, _options) {}
      extract_parent = ->(_options, data) { { name: data['name'], external_key: data['key'] } }
      extract_child = ->(_options, _data) { [{ name: 'IC2 Child', external_key: 'ic2-child' }] }

      @subject.import_classifications2(pipeline_import_object('ic2_step'), 'IC2 Tree', load_root, load_parent, extract_parent, extract_child, { import: {} })

      assert_not_nil(DataCycleCore::Classification.find_by(external_key: 'ic2-parent', external_source_id: @local_system.id))
      assert_not_nil(DataCycleCore::Classification.find_by(external_key: 'ic2-child', external_source_id: @local_system.id))
    end

    test 'import_classifications2 stops at max_count' do
      load_root = lambda do |_mongo_item, locale, _options|
        [
          { 'dump' => { locale => { 'name' => 'IC2M A', 'key' => 'ic2m-a' } } },
          { 'dump' => { locale => { 'name' => 'IC2M B', 'key' => 'ic2m-b' } } }
        ]
      end
      load_parent = ->(_data, _external_source_id, _options) {}
      extract_parent = ->(_options, data) { { name: data['name'], external_key: data['key'] } }
      extract_child = ->(_options, _data) { [] }

      @subject.import_classifications2(pipeline_import_object('ic2m_step'), 'IC2M Tree', load_root, load_parent, extract_parent, extract_child, { import: {}, max_count: 1 })

      assert_not_nil(DataCycleCore::Classification.find_by(external_key: 'ic2m-a', external_source_id: @local_system.id))
      assert_nil(DataCycleCore::Classification.find_by(external_key: 'ic2m-b', external_source_id: @local_system.id))
    end

    test 'import_classification reuses an existing polygon id when updating' do
      polygon = polygon_attributes
      @subject.import_classification(
        utility_object: @utility_object,
        classification_data: { name: 'Poly One', external_key: 'poly-1', tree_name: 'Poly Tree', classification_polygons_attributes: [polygon] }
      )
      updated_alias = @subject.import_classification(
        utility_object: @utility_object,
        classification_data: { name: 'Poly One', external_key: 'poly-1', tree_name: 'Poly Tree', classification_polygons_attributes: [polygon_attributes] }
      )

      assert_equal(1, updated_alias.classification_polygons.count)
    end

    test 'import_classifications logs partial progress every 100 items' do
      roots = (1..100).map { |i| { 'dump' => { de: { 'name' => "Batch #{i}", 'key' => "batch-#{i}" } } } }
      load_root = ->(_mongo_item, _locale, _options) { roots }
      load_child = ->(_mongo_item, _raw, _locale) { [] }
      load_parent = ->(_raw, _external_source_id, _options) {}
      extract = ->(_options, raw) { { name: raw['name'], external_key: raw['key'] } }

      @subject.import_classifications(pipeline_import_object('batch_step'), 'Batch Tree', load_root, load_child, load_parent, extract, { import: {} })

      assert_not_nil(DataCycleCore::Classification.find_by(external_key: 'batch-1', external_source_id: @local_system.id))
    end

    private

    def pipeline_import_object(name)
      DataCycleCore::Generic::ImportObject.new(
        external_source: @local_system,
        locales: [:de],
        import: {
          import_strategy: 'DataCycleCore::Generic::Common::ImportContents',
          source_type: 'things',
          name:
        }
      )
    end

    def polygon_attributes
      factory = RGeo::Geographic.spherical_factory(srid: 4326)
      ring = factory.linear_ring([factory.point(11.0, 46.0), factory.point(11.2, 46.0), factory.point(11.2, 46.2), factory.point(11.0, 46.2), factory.point(11.0, 46.0)])
      { geom: factory.polygon(ring) }
    end
  end
end
