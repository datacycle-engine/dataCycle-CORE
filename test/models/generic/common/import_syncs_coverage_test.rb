# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Generic
    module Common
      # Coverage for the ImportSyncs strategy. import_contents is stubbed (no
      # Mongo) and process_content runs through a real autoloaded transformation
      # (DummyCoverageTransformations) so the transform + process_syncs path runs.
      class ImportSyncsCoverageTest < DataCycleCore::TestCases::ActiveSupportTestCase
        def subject
          DataCycleCore::Generic::Common::ImportSyncs
        end

        def utility_object
          source = struct_double(id: '00000000-0000-0000-0000-000000000001', name: 'Sync ES', identifier: 'sync-es')
          object = Class.new {
            attr_accessor :locales

            define_method(:external_source) { source }
            define_method(:step_config) { |config| (config || {}).with_indifferent_access }
          }.new
          object.locales = [:de, :en]
          object
        end

        test 'load_contents builds the filtered query' do
          filter_object = Class.new {
            def with_locale = self
            def without_deleted = self
            def query = []
          }.new

          assert_equal([], subject.load_contents(filter_object:))
        end

        test 'import_data restricts to the first locale and delegates to import_contents' do
          object = utility_object

          DataCycleCore::Generic::Common::ImportFunctions.stub(:import_contents, nil) do
            subject.import_data(utility_object: object, options: { import: {} })
          end

          assert_equal([:de], object.locales)
        end

        test 'process_content transforms the item and calls process_syncs' do
          # external_system_data is absent, so process_syncs returns nil early -
          # the point is that the transform + process_syncs call path executes.
          result = subject.process_content(
            utility_object:,
            raw_data: { 'external_key' => 'k1', 'name' => 'Some Name' },
            locale: :de,
            options: {
              transformations: 'DummyCoverageTransformations',
              import: { template: 'POI', transformation: 'passthrough' }
            }
          )

          assert_nil(result)
        end

        test 'process_content returns nil for an id-only payload' do
          assert_nil(
            subject.process_content(
              utility_object:,
              raw_data: { 'id' => 'only-an-id' },
              locale: :de,
              options: { transformations: 'DummyCoverageTransformations', import: { transformation: 'passthrough' } }
            )
          )
        end
      end
    end
  end
end
