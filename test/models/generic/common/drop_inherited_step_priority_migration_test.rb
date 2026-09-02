# frozen_string_literal: true

require 'test_helper'
require DataCycleCore::Engine.root.join('db', 'data_migrate', '20260803090000_drop_inherited_step_priority_from_mongo_dumps')

module DataCycleCore
  # [#50666] The one case stripping the incoming payload cannot repair: an item that already carries a
  # foreign claim is unreachable, so the strip never gets to land on it.
  class DropInheritedStepPriorityMigrationTest < DataCycleCore::TestCases::ActiveSupportTestCase
    SUBJECT = DataCycleCore::Generic::Common::DownloadFunctions
    KEY = DataCycleCore::Generic::Common::Extensions::DumpKeyPolicy::STEP_PRIORITY_KEY

    before(:all) do
      @external_source = DataCycleCore::ExternalSystem.create!(
        name: 'Drop Inherited Step Priority Test System',
        identifier: 'drop-inherited-step-priority-test-system',
        config: {
          'download_config' => {
            'places' => { 'source_type' => 'dsp_places', 'priority' => 0 },
            'copy pois' => { 'source_type' => 'dsp_pois' }, # whole-dump copy of dsp_places, no priority
            'mixed prioritised' => { 'source_type' => 'dsp_mixed', 'priority' => 1 },
            'mixed plain' => { 'source_type' => 'dsp_mixed' },
            'frozen' => { 'source_type' => 'dsp_frozen', 'download_strategy' => SUBJECT.to_s },
            'many targets' => { 'source_type' => ['dsp_many_a', 'dsp_many_b'], 'priority' => 2 }
          }
        }
      )
    end

    after(:all) do
      DataCycleCore::MongoHelper.drop_mongo_db('drop-inherited-step-priority-test-system')
    end

    def download_object(source_type, name: 'migration test')
      DataCycleCore::Generic::DownloadObject.new(
        external_source: @external_source,
        locales: [:de],
        download: { source_type:, name:, download_strategy: SUBJECT.to_s }
      )
    end

    def seed_item(source_type, external_id, dump)
      object = download_object(source_type)
      object.with_mongodb do
        object.source_object.with(object.source_type) do |mongo_item|
          mongo_item.find_or_initialize_by(external_id:).tap { |item| item.dump = dump }.save!
        end
      end
    end

    def load_dump(source_type, external_id, locale = 'de')
      object = download_object(source_type)
      object.with_mongodb do
        object.source_object.with(object.source_type) do |mongo_item|
          mongo_item.where(external_id:).first&.dump&.dig(locale)
        end
      end
    end

    # scoped to this suite's system: migration#up walks every ExternalSystem, so unscoped it would
    # reach into whatever mongo db another suite happens to have left behind
    def run_migration
      migration = DropInheritedStepPriorityFromMongoDumps.new
      DataCycleCore::ExternalSystem.stub(:find_each, ->(&block) { block.call(@external_source) }) do
        migration.suppress_messages { migration.up }
      end
    end

    test 'drops the claims no step writing the collection could have made, keeps the rest' do
      seed_item('dsp_places', 'pl-1', { 'de' => { 'name' => 'Place 1', KEY => 0 } })
      seed_item('dsp_pois', 'po-1', { 'de' => { 'name' => 'Poi 1', KEY => 0 }, 'it' => { 'name' => 'Poi 1 it', KEY => 0 } })
      seed_item('dsp_mixed', 'mx-1', { 'de' => { 'name' => 'Mixed 1', KEY => 1 } })
      seed_item('dsp_orphan', 'or-1', { 'de' => { 'name' => 'Orphan 1', KEY => 0 } })

      run_migration

      # the target of an unprioritised step: nothing there can be a claim of ours
      assert_not load_dump('dsp_pois', 'po-1').key?(KEY)
      # off the configured locales, so out of reach of a config-driven migration -- re-adding `it`
      # later would bring the freeze back with it
      assert_not load_dump('dsp_pois', 'po-1', 'it').key?(KEY)
      # no step at all writes this collection, so the config never names it
      assert_not load_dump('dsp_orphan', 'or-1').key?(KEY)

      assert_equal 0, load_dump('dsp_places', 'pl-1')[KEY] # written by a prioritised step
      # written by a prioritised *and* an unprioritised step: indistinguishable by now, and dropping
      # would cost the legitimate claim its protection
      assert_equal 1, load_dump('dsp_mixed', 'mx-1')[KEY]

      assert_equal 'Poi 1', load_dump('dsp_pois', 'po-1')['name'] # nothing but the key is touched
    end

    test 'a prioritised step naming several source_types protects all of them' do
      # Import#relevant_steps_for reads source_type as one-or-many, so a scalar-only read here would
      # drop legitimate claims from every collection after the first
      seed_item('dsp_many_a', 'ma-1', { 'de' => { 'name' => 'Many A', KEY => 2 } })
      seed_item('dsp_many_b', 'mb-1', { 'de' => { 'name' => 'Many B', KEY => 2 } })

      run_migration

      assert_equal 2, load_dump('dsp_many_a', 'ma-1')[KEY]
      assert_equal 2, load_dump('dsp_many_b', 'mb-1')[KEY]
    end

    test 'keeps a stored default, which blocks nothing and props_from_config would write straight back' do
      # the concept strategies stamp DEFAULT_STEP_PRIORITY on what they write while configuring no
      # priority of their own, so their targets look unclaimable while their stored value is ours.
      # Dropping it changes no decision (5 <= 5 passes either way) but would make the next download
      # rewrite every concept dump - the mass rewrite !241 exists to avoid.
      default = DataCycleCore::Generic::Common::Extensions::DumpKeyPolicy::DEFAULT_STEP_PRIORITY
      seed_item('dsp_concepts', 'co-1', { 'de' => { 'name' => 'Concept 1', KEY => default } })
      seed_item('dsp_concepts', 'co-2', { 'de' => { 'name' => 'Concept 2', KEY => '0' } }) # no claim, no freeze

      run_migration

      assert_equal default, load_dump('dsp_concepts', 'co-1')[KEY]
      assert_equal '0', load_dump('dsp_concepts', 'co-2')[KEY], '$lt must not match across BSON types'
    end

    test 'is idempotent' do
      seed_item('dsp_idem', 'id-1', { 'de' => { 'name' => 'Idem 1', KEY => 0 } })

      2.times { run_migration }

      assert_not load_dump('dsp_idem', 'id-1').key?(KEY)
      assert_equal 'Idem 1', load_dump('dsp_idem', 'id-1')['name']
    end

    test 'an item frozen by an inherited claim is writable again afterwards' do
      # the freeze in full: dsp_pois inherited dsp_places' claim of 0 through a whole-dump copy, so
      # its own unprioritised step lost against it from the second run on (5 <= 0 is false) and the
      # dump stopped changing. !241 stops new writes from inheriting a claim, but the stored one gates
      # the write itself, so only this migration gets the item moving again.
      seed_item('dsp_frozen', 'fr-1', { 'de' => { 'name' => 'Frozen 1', KEY => 0 } })

      download = lambda { |name|
        SUBJECT.download_content(
          download_object: download_object('dsp_frozen', name: 'frozen'),
          iterator: ->(**_kwargs) { [{ 'id' => 'fr-1', 'name' => name }] },
          data_id: ->(data) { data['id'] },
          data_name: ->(data) { data['name'] },
          options: { locales: [:de], download: {} }
        )
      }

      download.call('Frozen 1 renamed')

      assert_equal 'Frozen 1', load_dump('dsp_frozen', 'fr-1')['name'], 'the inherited claim must refuse the write'

      run_migration
      download.call('Frozen 1 renamed')

      assert_equal 'Frozen 1 renamed', load_dump('dsp_frozen', 'fr-1')['name']
    end

    test 'is irreversible' do
      assert_raises(ActiveRecord::IrreversibleMigration) { DropInheritedStepPriorityFromMongoDumps.new.down }
    end
  end
end
