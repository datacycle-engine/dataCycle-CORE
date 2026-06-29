# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Serialize
    module Serializer
      class IdMappingTest < DataCycleCore::TestCases::ActiveSupportTestCase
        before(:all) do
          @user = DataCycleCore::User.find_by(email: 'tester@datacycle.at')
          @thing = DataCycleCore::TestPreparations.create_content(
            template_name: 'Artikel',
            data_hash: { name: 'IdMapping Article', external_key: 'IDM-1' },
            user: @user
          )
        end

        def serializer
          DataCycleCore::Serialize::Serializer::IdMapping
        end

        # --- flags / config -----------------------------------------------------
        test 'translatable? is false' do
          assert_not(serializer.translatable?)
        end

        test 'config_hash returns the serializer config or an empty hash' do
          DataCycleCore::Feature::Serialize.stub(:enabled_serializers, { 'id_mapping' => { 'dc_link' => true } }) do
            assert_equal({ 'dc_link' => true }, serializer.send(:config_hash))
          end
          DataCycleCore::Feature::Serialize.stub(:enabled_serializers, { 'id_mapping' => 'not-a-hash' }) do
            assert_equal({}, serializer.send(:config_hash))
          end
        end

        # --- SQL fragment builders (pure) --------------------------------------
        test 'concept_scheme_sql builds joins for hash and array configs, blank otherwise' do
          serializer.stub(:config_hash, { 'concept_scheme_ids' => { 'ids' => ['00000000-0000-0000-0000-000000000001'], 'attribute' => 'external_key' } }) do
            result = serializer.send(:concept_scheme_sql)

            assert_equal(2, result.size)
            assert_includes(result[0], 'concept_schemes')
          end
          # plain Array config (no custom attribute) defaults to external_key
          serializer.stub(:config_hash, { 'concept_scheme_ids' => ['00000000-0000-0000-0000-000000000002'] }) do
            assert_equal(2, serializer.send(:concept_scheme_sql).size)
          end
          # nil/blank config takes the non-Hash Array.wrap branch and returns []
          serializer.stub(:config_hash, {}) do
            assert_equal([], serializer.send(:concept_scheme_sql))
          end
        end

        test 'dc_link_sql builds a URL column when enabled' do
          serializer.stub(:config_hash, { 'dc_link' => true }) do
            assert_includes(serializer.send(:dc_link_sql), 'dc_link')
          end
          serializer.stub(:config_hash, {}) do
            assert_equal('', serializer.send(:dc_link_sql))
          end
        end

        test 'name_sql builds a translation join for string/true configs, blank otherwise' do
          serializer.stub(:config_hash, { 'name' => 'de' }) do
            assert_equal(2, serializer.send(:name_sql).size)
          end
          serializer.stub(:config_hash, { 'name' => true }) do
            assert_equal(2, serializer.send(:name_sql).size)
          end
          serializer.stub(:config_hash, {}) do
            assert_equal([], serializer.send(:name_sql))
          end
        end

        test 'external_system_syncs_sql builds joins unless disabled' do
          serializer.stub(:config_hash, {}) do
            assert_equal(2, serializer.send(:external_system_syncs_sql).size)
          end
          serializer.stub(:config_hash, { 'external_system_syncs' => false }) do
            assert_equal([], serializer.send(:external_system_syncs_sql))
          end
        end

        # --- pure data transforms ----------------------------------------------
        test 'data_headers counts the maximum occurrences per key' do
          data = [
            { 'external_system' => ['A'], 'external_relations' => [{ 'external_system' => 'A' }, { 'external_system' => 'B' }] },
            { 'external_system' => ['A'], 'external_relations' => [{ 'external_system' => 'A' }] }
          ]
          headers = serializer.send(:data_headers, data, ->(v) { Array.wrap(v['external_system']) + Array.wrap(v['external_relations']&.pluck('external_system')) })

          assert_equal({ 'A' => 2, 'B' => 1 }, headers)
        end

        test 'data_to_csv renders ids, urls, names and relation columns' do
          data = [{
            'id' => 'thing-1', 'dc_link' => 'https://x/things/thing-1', 'name' => 'Row',
            'external_system' => 'Feratel', 'external_key' => 'EXT-1',
            'external_relations' => [{ 'external_system' => 'Other', 'external_key' => 'O-1' }],
            'concept_schemes' => [{ 'concept_scheme' => 'Scheme', 'external_key' => 'CS-1' }]
          }]
          csv = serializer.send(:data_to_csv, data, ['Id', 'URL', 'Name', 'Feratel', 'Other', 'Scheme'], { 'Feratel' => 1, 'Other' => 1 }, { 'Scheme' => 1 })

          assert_includes(csv, 'thing-1')
          assert_includes(csv, 'https://x/things/thing-1')
          assert_includes(csv, 'EXT-1')
          assert_includes(csv, 'O-1')
          assert_includes(csv, 'CS-1')
        end

        # --- full serialize chain (executes SQL) -------------------------------
        test 'serialize_thing produces a CSV content collection' do
          serializer.stub(:config_hash, { 'dc_link' => true, 'name' => 'de', 'concept_scheme_ids' => { 'ids' => ['00000000-0000-0000-0000-000000000001'] }, 'external_system_syncs' => true }) do
            result = serializer.serialize_thing(content: @thing, language: 'de', user: @user)

            assert_kind_of(DataCycleCore::Serialize::SerializedData::ContentCollection, result)
          end
        end

        test 'serialize_contents builds relation headers from the result rows' do
          raw = [{
            'id' => @thing.id, 'external_system' => 'Sys', 'external_key' => 'K',
            'external_relations' => [{ 'external_system' => 'Sys', 'external_key' => 'K' }],
            'concept_schemes' => [{ 'concept_scheme' => 'Scheme', 'external_key' => 'CS' }]
          }]

          serializer.stub(:config_hash, { 'dc_link' => true, 'name' => 'de' }) do
            serializer.stub(:result, raw) do
              collection = serializer.send(:serialize_contents, contents: DataCycleCore::Thing.where(id: @thing.id), content: @thing, language: 'de', user: @user)

              assert_kind_of(DataCycleCore::Serialize::SerializedData::ContentCollection, collection)
            end
          end
        end

        test 'serialize_watch_list and serialize_stored_filter serialize their contents' do
          watch_list = DataCycleCore::WatchList.create!(name: 'IdMapping WL', full_path: 'IdMapping WL', user_id: @user.id)

          serializer.stub(:config_hash, {}) do
            assert_kind_of(DataCycleCore::Serialize::SerializedData::ContentCollection, serializer.serialize_watch_list(content: watch_list, language: 'de', user: @user))
          end

          stored_filter = DataCycleCore::StoredFilter.create!(name: 'IdMapping SF', user_id: @user.id)

          serializer.stub(:config_hash, {}) do
            assert_kind_of(DataCycleCore::Serialize::SerializedData::ContentCollection, serializer.serialize_stored_filter(content: stored_filter, language: 'de', user: @user))
          end
        end
      end
    end
  end
end
