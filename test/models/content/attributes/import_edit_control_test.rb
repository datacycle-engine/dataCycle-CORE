# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Content
    module Attributes
      # Behaviour of the import & edit control flags documented in guides/overview.md
      # ("Import & edit control (`global`, `local`, `external`)") for Redmine #49247.
      #
      # The flags are implemented through the property-classification helpers that the
      # import pipeline consumes (see generic/common/import_functions_data_helper.rb):
      #   * importable_property_names        -> incoming import data is sliced to these (:49)
      #   * local_property_names             -> additionally stripped from import data (:134)
      #   * resettable_import_property_names -> reset to nil only on a primary-source change
      #                                         (change_primary_system!, :479)
      #
      # `external:` is intentionally not covered here: it is deprecated and its
      # external_property_names selector is currently not consumed anywhere in app/lib.
      class ImportEditControlTest < DataCycleCore::TestCases::ActiveSupportTestCase
        TEMPLATE = 'ImportEditControl'

        before(:all) do
          @external_source = DataCycleCore::ExternalSystem.create!(
            name: 'Import Edit Control Test System',
            identifier: 'import-edit-control-test-system',
            config: {
              'import_config' => {
                'import edit control' => {
                  'source_type' => 'iec_things',
                  'import_strategy' => 'DataCycleCore::Generic::Common::ImportContents'
                }
              }
            }
          )
        end

        after(:all) do
          DataCycleCore::MongoHelper.drop_mongo_db('import-edit-control-test-system')
        end

        def utility_object
          DataCycleCore::Generic::ImportObject.new(
            external_source: @external_source,
            locales: [:de],
            import: {
              source_type: 'iec_things',
              name: 'import edit control',
              import_strategy: 'DataCycleCore::Generic::Common::ImportContents'
            }
          )
        end

        # Run a single dataset through the real import write path (no Mongo/download needed,
        # raw_data is provided directly) and return the created/updated content.
        def import!(raw_data)
          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object:,
            raw_data:,
            transformation: ->(data) { data },
            default: { template: TEMPLATE },
            config: {}
          )
        end

        # ---- documented contract: property classification ----

        test 'global and local flags classify properties into the correct property-name sets' do
          content = create_content(TEMPLATE, { name: 'Contract' })

          assert_includes content.global_property_names.map(&:to_s), 'global_attr'
          assert_includes content.local_property_names.map(&:to_s), 'local_attr'

          # local is never importable; global (and a plain attribute) are
          importable = content.importable_property_names.map(&:to_s)

          assert_includes importable, 'global_attr'
          assert_includes importable, 'default_attr'
          assert_not_includes importable, 'local_attr'

          # both global and local stay locally editable (writable)
          writable = content.writable_property_names.map(&:to_s)

          assert_includes writable, 'global_attr'
          assert_includes writable, 'local_attr'

          # on a primary-source change only plain attributes are reset; global/local are kept
          resettable = content.resettable_import_property_names.map(&:to_s)

          assert_includes resettable, 'default_attr'
          assert_not_includes resettable, 'global_attr'
          assert_not_includes resettable, 'local_attr'
        end

        # ---- local: never imported, always locally editable ----

        test 'local attribute is ignored by the importer' do
          content = import!({ 'external_key' => 'iec-local-1', 'name' => 'Local 1', 'default_attr' => 'imported', 'local_attr' => 'from import' })

          assert_predicate content, :persisted?
          assert_equal 'imported', content.default_attr # a plain attribute IS imported
          assert_nil content.local_attr                 # the local attribute is NOT
        end

        test 'local attribute is locally editable and retained across re-imports' do
          content = import!({ 'external_key' => 'iec-local-2', 'name' => 'Local 2', 'default_attr' => 'd1' })

          content.set_data_hash(data_hash: { 'local_attr' => 'edited locally' })

          assert_equal 'edited locally', content.reload.local_attr

          # re-import (changed default_attr forces processing) must neither overwrite nor reset the local value
          import!({ 'external_key' => 'iec-local-2', 'name' => 'Local 2', 'default_attr' => 'd2', 'local_attr' => 'import again' })

          assert_equal 'd2', content.reload.default_attr # plain attribute updated by import
          assert_equal 'edited locally', content.local_attr # local value untouched
        end

        # ---- global: last-writer-wins ----

        test 'global attribute is written by the importer' do
          content = import!({ 'external_key' => 'iec-global-1', 'name' => 'Global 1', 'global_attr' => 'import value' })

          assert_equal 'import value', content.global_attr
        end

        test 'global attribute is last-writer-wins between importer and local editor' do
          content = import!({ 'external_key' => 'iec-global-2', 'name' => 'Global 2', 'global_attr' => 'import 1' })

          assert_equal 'import 1', content.global_attr

          # local editor writes last -> local value wins (edit is allowed on imported global attributes)
          content.set_data_hash(data_hash: { 'global_attr' => 'edited locally' })

          assert_equal 'edited locally', content.reload.global_attr

          # importer writes last -> import value wins
          import!({ 'external_key' => 'iec-global-2', 'name' => 'Global 2', 'global_attr' => 'import 2' })

          assert_equal 'import 2', content.reload.global_attr
        end

        test 'global attribute is retained when omitted from a later import' do
          content = import!({ 'external_key' => 'iec-global-3', 'name' => 'Global 3', 'default_attr' => 'd1', 'global_attr' => 'keep me' })

          assert_equal 'keep me', content.global_attr

          # later import without global_attr (changed default_attr forces processing) leaves it untouched
          import!({ 'external_key' => 'iec-global-3', 'name' => 'Global 3', 'default_attr' => 'd2' })

          assert_equal 'd2', content.reload.default_attr
          assert_equal 'keep me', content.global_attr
        end
      end
    end
  end
end
