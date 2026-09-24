# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Generic
    # [#51777] The mode vocabulary is split across DownloadObject::FULL_MODES and
    # ImportObject::DELTA_MODES, and full_delta is the one name in both. A mode that reaches neither
    # list still runs -- GenericObject takes any string -- and resolves to a delta download plus a
    # full import, the inverse of every named mode. So the pair is pinned per stage here rather than
    # left to the two constants to agree by inspection.
    class ModeResolutionTest < DataCycleCore::TestCases::ActiveSupportTestCase
      LAST_SUCCESSFUL_TRY = Time.zone.local(2020, 1, 1)
      # mode => whether each stage keeps the lower bound (:delta) or drops it (:full)
      EXPECTED = {
        'incremental' => { download: :delta, import: :delta },
        'full_delta' => { download: :full, import: :delta },
        'full' => { download: :full, import: :full },
        'reset' => { download: :full, import: :full }
      }.freeze
      STRATEGIES = {
        download: 'DataCycleCore::Generic::Common::DownloadFunctions',
        import: 'DataCycleCore::Generic::Common::ImportContents'
      }.freeze

      before(:all) do
        @external_source = DataCycleCore::ExternalSystem.create!(
          name: 'Mode Resolution Test System',
          identifier: 'mode-resolution-test-system'
        )
      end

      after(:all) do
        DataCycleCore::MongoHelper.drop_mongo_db('mode-resolution-test-system')
      end

      def object_for(type, mode)
        klass = type == :download ? DownloadObject : ImportObject

        klass.new(
          external_source: @external_source,
          mode:,
          type => { source_type: 'mrt_things', name: 'mode test', "#{type}_strategy": STRATEGIES[type] }
        )
      end

      EXPECTED.each do |mode, stages|
        stages.each do |type, bound|
          test "the #{type} stage in #{mode} mode #{bound == :full ? 'drops' : 'keeps'} the lower bound" do
            object = object_for(type, mode)

            object.stub(:last_successful_try, LAST_SUCCESSFUL_TRY) do
              if bound == :full
                assert_nil object.changed_from
              else
                assert_equal LAST_SUCCESSFUL_TRY, object.changed_from
              end
            end
          end
        end
      end

      # Fails when a mode is added to either constant without a line in EXPECTED, which is the omission
      # that would otherwise only show up as a run of the wrong size.
      test 'every mode in the two constants is covered by EXPECTED' do
        assert_equal EXPECTED.keys.sort, (DownloadObject::FULL_MODES | ImportObject::DELTA_MODES).sort
      end
    end
  end
end
