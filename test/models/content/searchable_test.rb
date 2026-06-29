# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Content
    # Coverage for the Content::Searchable scopes / class methods (mixed into Thing).
    class SearchableTest < DataCycleCore::TestCases::ActiveSupportTestCase
      before(:all) do
        @local_system = DataCycleCore::ExternalSystem.find_by(identifier: 'local-system')
      end

      def thing
        DataCycleCore::Thing
      end

      test 'simple where-based scopes build executable queries' do
        assert_kind_of(Integer, thing.with_content_type('entity').count)
        assert_kind_of(Integer, thing.without_template_names('Artikel').count)
        assert_kind_of(Integer, thing.with_template_names('Artikel').count)
      end

      test 'template-schema scopes build relations' do
        # reference thing_templates → build only (no #count, which would need the join)
        assert_kind_of(ActiveRecord::Relation, thing.with_schema_type('creative_work'))
        assert_kind_of(ActiveRecord::Relation, thing.with_default_data_type(['Artikel']))
      end

      test 'expired_not_release_id respects the Releasable feature' do
        DataCycleCore::Feature::Releasable.stub(:enabled?, false) do
          assert_nil(thing.expired_not_release_id('x'))
        end

        DataCycleCore::Feature::Releasable.stub(:enabled?, true) do
          assert_kind_of(ActiveRecord::Relation, thing.expired_not_release_id(SecureRandom.uuid))
        end
      end

      test 'expired_not_life_cycle_id respects the LifeCycle feature' do
        DataCycleCore::Feature::LifeCycle.stub(:attribute_keys, []) do
          assert_nil(thing.expired_not_life_cycle_id('x'))
        end

        DataCycleCore::Feature::LifeCycle.stub(:attribute_keys, ['life_cycle']) do
          assert_kind_of(ActiveRecord::Relation, thing.expired_not_life_cycle_id(SecureRandom.uuid))
        end
      end

      test 'by_external_system returns none for a blank id and builds a join otherwise' do
        assert_equal(0, thing.by_external_system(nil).count)
        assert_kind_of(ActiveRecord::Relation, thing.by_external_system(@local_system.id))
      end

      test 'by_current_identified_syncs_subquery resolves current ids' do
        @local_system.stub(:default_options, { 'current_instance_identifiers' => ['id1'] }) do
          syncs = [{ 'identifier' => 'id1', 'external_key' => SecureRandom.uuid }]
          subquery, = thing.by_current_identified_syncs_subquery(@local_system, syncs)

          assert_kind_of(String, subquery)
        end
      end

      test 'by_primary_sync_subquery resolves the primary system' do
        syncs = [{ 'primary' => true, 'external_key' => 'pk', 'identifier' => 'local-system' }]
        subquery, = thing.by_primary_sync_subquery(@local_system, syncs)

        assert_kind_of(String, subquery)
      end

      test 'by_existing_syncs_subquery builds a subquery per existing sync' do
        syncs = [{ 'identifier' => 'local-system', 'external_key' => 'ek' }]

        @local_system.stub(:default_options, {}) do
          result = thing.by_existing_syncs_subquery(@local_system, syncs)

          assert_kind_of(String, result.first&.first)
        end
      end
    end
  end
end
