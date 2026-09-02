# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  # Second wave of the per-file Models >=90% floor push: a few models that sat just
  # below the line and are reachable with seeded records + light doubles.
  class UnderNinetyBatchFCoverageTest < DataCycleCore::TestCases::ActiveSupportTestCase
    # --- TestData::AssetSource -------------------------------------------------
    test 'AssetSource#existing_id resolves an asset id and rescues errors' do
      source = DataCycleCore::TestData::AssetSource.new

      assert_nothing_raised { source.send(:existing_id, 'image') }

      source.stub(:model, ->(*) { raise 'boom' }) do
        assert_nil source.send(:existing_id, 'image')
        assert_nil source.send(:create_from_fixture, 'image')
      end
    end

    # --- Classification --------------------------------------------------------
    test 'Classification mapped_to / ancestors / descendants resolve from the primary alias' do
      classification = DataCycleCore::ClassificationAlias.for_tree('Tags').first&.primary_classification

      skip 'no seeded Tags classification' if classification.nil?

      assert_respond_to classification.mapped_to, :to_a
      assert_kind_of Array, classification.ancestors
      assert_kind_of Array, classification.descendants
    end

    # --- StoredFilterExtensions::FilterParamsHashParser ------------------------
    test 'relevant_for_object_browser? matches restrictions against the content' do
      stored_filter = DataCycleCore::StoredFilter.new

      assert stored_filter.send(:relevant_for_object_browser?, { 'object_browser_restriction' => nil }, {})
      assert_not stored_filter.send(:relevant_for_object_browser?, { 'object_browser_restriction' => { 'POI' => ['image'] } }, { content: nil })

      content = Object.new
      content.define_singleton_method(:relevant_template_names) { ['POI'] }
      content.define_singleton_method(:relevant_property_names) { |_key| ['image'] }

      assert stored_filter.send(
        :relevant_for_object_browser?,
        { 'object_browser_restriction' => { 'POI' => ['image'] } },
        { content:, attribute_key: 'image' }
      )
    end

    # --- ExternalSystemSync ----------------------------------------------------
    test 'ExternalSystemSync class scopes and to_hash build data hashes' do
      assert_nil DataCycleCore::ExternalSystemSync.with_external_system(SecureRandom.uuid)
      assert_kind_of Array, DataCycleCore::ExternalSystemSync.to_external_data_hash

      hash = DataCycleCore::ExternalSystemSync.new(external_system: DataCycleCore::ExternalSystem.first).to_hash

      assert hash.key?(:external_identifier)
    end

    test 'ExternalSystemSync#external_url dispatches to a configured url method' do
      sync = DataCycleCore::ExternalSystemSync.new(external_key: 'key-1')
      thing = DataCycleCore::Thing.new(template_name: DataCycleCore::ThingTemplate.first.template_name)
      external_system = Object.new
      external_system.define_singleton_method(:default_options) { |_| { 'external_url' => 'https://x.test/', 'external_url_method' => 'append_external_key' } }

      sync.stub(:syncable, thing) do
        sync.stub(:external_system, external_system) do
          sync.stub(:data, {}) do
            assert_equal 'https://x.test/key-1', sync.external_url
          end
        end
      end
    end
  end
end
