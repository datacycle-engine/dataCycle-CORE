# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class DuplicateCandidateTest < DataCycleCore::TestCases::ActiveSupportTestCase
    include ActiveJob::TestHelper

    before(:all) do
      updates = []
      bild_template = DataCycleCore::ThingTemplate.find_by(template_name: 'Bild')
      updates << { template_name: bild_template.template_name, schema: bild_template.schema.deep_merge('features' => { 'duplicate_candidate' => { 'allowed' => true, 'module' => 'BildPhash' } }) }
      place_template = DataCycleCore::ThingTemplate.find_by(template_name: 'Örtlichkeit')
      updates << { template_name: place_template.template_name, schema: place_template.schema.deep_merge('features' => { 'duplicate_candidate' => { 'allowed' => true, 'module' => ['OnlyTitle', 'NameSimilarity'] } }) }
      DataCycleCore::ThingTemplate.upsert_all(updates, unique_by: :template_name)
    end

    test 'find duplicates for images' do
      assert_predicate DataCycleCore::Feature::DuplicateCandidate, :enabled?

      image1 = upload_image('test_rgb.jpeg')

      assert_predicate image1.thumb_preview, :present?
      content1 = create_content('Bild', { name: 'Test Bild 1', asset: image1.id })

      image2 = upload_image('test_rgb.png')

      assert_predicate image2.thumb_preview, :present?
      content2 = create_content('Bild', { name: 'Test Bild 2', asset: image2.id })

      image3 = upload_image('test_rgb.gif')

      assert_predicate image3.thumb_preview, :present?
      content3 = create_content('Bild', { name: 'Test Bild 3', asset: image3.id })

      image4 = upload_image('test_cmyk.jpeg')

      assert_predicate image4.thumb_preview, :present?
      content4 = create_content('Bild', { name: 'Test Bild 4', asset: image4.id })

      image5 = upload_image('test_rgb_portrait.jpeg')

      assert_predicate image5.thumb_preview, :present?
      content5 = create_content('Bild', { name: 'Test Bild 5', asset: image5.id })

      assert_equal 3, content1.duplicate_candidates.reload.size
      assert_equal 3, content2.duplicate_candidates.reload.size
      assert_equal 3, content3.duplicate_candidates.reload.size
      assert_equal 3, content4.duplicate_candidates.reload.size
      assert_empty content5.duplicate_candidates.reload
      assert_equal [content2.id, content3.id, content4.id].sort, content1.duplicates.pluck(:id).sort
      assert_equal [content1.id, content3.id, content4.id].sort, content2.duplicates.pluck(:id).sort
      assert_equal [content1.id, content2.id, content4.id].sort, content3.duplicates.pluck(:id).sort
      assert_equal [content1.id, content2.id, content3.id].sort, content4.duplicates.pluck(:id).sort
    end

    test 'merge with duplicate' do
      assert_predicate DataCycleCore::Feature::DuplicateCandidate, :enabled?

      image1 = create_content('Bild', { name: 'Test Bild 1' })
      image2 = create_content('Bild', { name: 'Test Bild 2' })
      image3 = create_content('Bild', { name: 'Test Bild 3' })

      content1 = create_content('POI', { name: 'Test Artikel 1', image: [image2.id, image3.id], primary_image: [image2.id], logo: [image2.id, image3.id] })
      content2 = create_content('POI', { name: 'Test Artikel 2', image: [image1.id, image2.id], primary_image: [image1.id], logo: [image1.id, image2.id] })
      content3 = create_content('POI', { name: 'Test Artikel 3', image: [image1.id], primary_image: [image2.id], logo: [image2.id] })

      content1.set_data_hash(data_hash: { name: 'TestArtikel 1' }.deep_stringify_keys, partial_update: true)
      content2.set_data_hash(data_hash: { name: 'TestArtikel 2' }.deep_stringify_keys, partial_update: true)
      content3.set_data_hash(data_hash: { name: 'TestArtikel 2' }.deep_stringify_keys, partial_update: true)
      perform_enqueued_jobs

      image1.merge_with_duplicate(image2)
      perform_enqueued_jobs

      assert_nil DataCycleCore::Thing.find_by(id: image2.id)

      # FIXME: Destroying a content removes content_relations in the history entries
      assert_equal [image1.id, image3.id], content1.image.pluck(:id)
      assert_equal [image1.id], content1.primary_image.pluck(:id)
      assert_equal [image1.id, image3.id], content1.logo.pluck(:id)
      # assert_equal [image1.id, image3.id], content1.histories.first.image.pluck(:id)
      # assert_equal [image1.id], content1.histories.first.primary_image.pluck(:id)
      # assert_equal [image1.id, image3.id], content1.histories.first.logo.pluck(:id)

      assert_equal [image1.id], content2.image.pluck(:id)
      assert_equal [image1.id], content2.primary_image.pluck(:id)
      assert_equal [image1.id], content2.logo.pluck(:id)
      # assert_equal [image1.id], content2.histories.first.image.pluck(:id)
      # assert_equal [image1.id], content2.histories.first.primary_image.pluck(:id)
      # assert_equal [image1.id], content2.histories.first.logo.pluck(:id)

      assert_equal [image1.id], content3.image.pluck(:id)
      assert_equal [image1.id], content3.primary_image.pluck(:id)
      assert_equal [image1.id], content3.logo.pluck(:id)
      # assert_equal [image1.id], content3.histories.first.image.pluck(:id)
      # assert_equal [image1.id], content3.histories.first.primary_image.pluck(:id)
      # assert_equal [image1.id], content3.histories.first.logo.pluck(:id)
    end

    # move_linked_content moves the timestamps of the content it moves, and so that content's own
    # payload cache key; the contents linking it keep theirs, and the merge invalidates nothing else
    test 'the merge hands the re-export of the linking contents its cache invalidation' do
      image1 = create_content('Bild', { name: 'Merge Invalidate Bild 1' })
      image2 = create_content('Bild', { name: 'Merge Invalidate Bild 2' })
      poi = create_content('POI', { name: 'Merge Invalidate POI', image: [image2.id] })
      # the POI is what the merge moves and fans out from, so something has to link it in turn
      create_content('Vererbte Sprachen', { name: 'Merge Invalidate Reference', plain_reference: [poi.id] })

      args = []
      DataCycleCore::RelatedWebhooksJob.stub(:perform_later, ->(*a) { args << a }) do
        DataCycleCore::Webhook::Update.stub(:execute_all, ->(*, **) {}) do
          DataCycleCore.stub(:webhooks, ['Merge Invalidate ES']) do
            image1.merge_with_duplicate(image2)
            perform_enqueued_jobs
          end
        end
      end

      assert_includes args.map { |a| [a[0], a[3]] }, [poi.id, true]
    end

    test 'merge triggered by a user deletes the duplicate inline' do
      user = DataCycleCore::User.find_by(email: 'tester@datacycle.at')
      image1 = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: { name: 'Test Bild 1' })
      image2 = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: { name: 'Test Bild 2' })
      content = DataCycleCore::TestPreparations.create_content(template_name: 'POI', data_hash: { name: 'Test POI 1', image: [image2.id] })

      assert DataCycleCore::Feature::DuplicateCandidate.merge_inline?(image2)

      DataCycleCore::MergeDuplicateJob.stub(:perform_later, ->(*) { raise 'merge must not be queued' }) do
        image1.merge_with_duplicate(image2, current_user: user, async: false)
      end

      assert_nil DataCycleCore::Thing.find_by(id: image2.id)
      assert_equal [image1.id], content.image.pluck(:id)
      assert_equal user.id, DataCycleCore::Thing::History.where(thing_id: image2.id).where.not(deleted_at: nil).first&.deleted_by
    end

    # TestPreparations.create_content reuses an existing content with the same name, so colliding
    # titles have to be produced by renaming afterwards, not by creating two contents with one name.
    def create_place_pair_with_equal_titles
      shared_title = "Duplicate Place #{SecureRandom.hex(4)}"
      place1 = DataCycleCore::TestPreparations.create_content(template_name: 'Örtlichkeit', data_hash: { name: shared_title })
      place2 = DataCycleCore::TestPreparations.create_content(template_name: 'Örtlichkeit', data_hash: { name: "Other Place #{SecureRandom.hex(4)}" })
      place2.set_data_hash(data_hash: { 'name' => shared_title }, partial_update: true)
      place1.create_duplicate_candidates

      [place1, place2]
    end

    test 'manually marked duplicates survive a recalculation of the candidates' do
      place1, place2 = create_place_pair_with_equal_titles
      manual_place = DataCycleCore::TestPreparations.create_content(template_name: 'Örtlichkeit', data_hash: { name: "Manually Marked #{SecureRandom.hex(4)}" })

      assert_equal [place2.id], place1.duplicate_candidates.reload.pluck(:duplicate_id).uniq

      DataCycleCore::ThingDuplicate.create!(thing_id: place1.id, thing_duplicate_id: manual_place.id, method: 'manual', score: 100)
      place1.create_duplicate_candidates

      # the automatic pair is re-found by the configured modules, the manual one is found by no
      # module at all and would be cleaned up without the reserved-method guard
      candidates = place1.duplicate_candidates.reload

      assert_equal [manual_place.id, place2.id].sort, candidates.pluck(:duplicate_id).uniq.sort
      assert_equal ['manual'], candidates.select { |c| c.duplicate_id == manual_place.id }.map(&:duplicate_method)
    end

    test 'a manual marking coexists with the automatic candidates of the same pair' do
      place1, place2 = create_place_pair_with_equal_titles
      automatic_methods = place1.duplicate_candidates.reload.map(&:duplicate_method)

      assert_predicate automatic_methods, :present?
      assert_not_includes automatic_methods, 'manual'

      # the unique index covers (thing_ids, method), so a manual row is added next to the automatic
      # ones instead of overwriting one of them
      DataCycleCore::ThingDuplicate.create!(thing_id: place1.id, thing_duplicate_id: place2.id, method: 'manual', score: 100)
      place1.create_duplicate_candidates

      methods = place1.duplicate_candidates.reload.select { |c| c.duplicate_id == place2.id }.map(&:duplicate_method)

      assert_includes methods, 'manual'
      assert_equal automatic_methods.sort, (methods - ['manual']).sort
    end

    test 'manually marked duplicates survive a recalculation without any automatic matches' do
      place1 = DataCycleCore::TestPreparations.create_content(template_name: 'Örtlichkeit', data_hash: { name: "Lonely Place #{SecureRandom.hex(4)}" })
      manual_place = DataCycleCore::TestPreparations.create_content(template_name: 'Örtlichkeit', data_hash: { name: "Manually Marked #{SecureRandom.hex(4)}" })

      DataCycleCore::ThingDuplicate.create!(thing_id: place1.id, thing_duplicate_id: manual_place.id, method: 'manual', score: 100)
      place1.create_duplicate_candidates

      assert_equal [manual_place.id], place1.duplicate_candidates.reload.pluck(:duplicate_id)
    end

    # +count+ places that all carry the same title, so every configured module finds every pair.
    def create_places_with_equal_titles(count)
      shared_title = "Duplicate Place #{SecureRandom.hex(4)}"

      Array.new(count) { DataCycleCore::TestPreparations.create_content(template_name: 'Örtlichkeit', data_hash: { name: "Other Place #{SecureRandom.hex(4)}" }) }
        .each { |place| place.set_data_hash(data_hash: { 'name' => shared_title }, partial_update: true) }
    end

    # The candidate rows of +content+ as unique_thing_duplicate_idx keys them.
    def index_keys(content)
      content.find_duplicates.map { |t| [*[content.id, t[:thing_duplicate_id]].minmax, t[:method]] }
    end

    test 'candidate rows are inserted in the order of their unique index key' do
      keys = create_places_with_equal_titles(3).map { |place| index_keys(place) }

      # two modules find each of the two pairs a place belongs to: in score order those four rows
      # come out grouped by method, which is an order the other end of a pair does not share
      assert_equal [4, 4, 4], keys.map(&:size)
      keys.each { |k| assert_equal k.sort, k }

      # the consequence, and the reason for the sort: the keys the two ends of a pair share come out
      # in the same relative order on both sides, so no two workers can cross on one
      shared = keys[0] & keys[1]

      assert_operator shared.size, :>=, 2
      assert_equal shared, keys[1] & keys[0]
    end

    test 'a pair reported once per matching translation becomes a single candidate row per method' do
      place1, place2 = create_place_pair_with_equal_titles
      shared_title = place1.name

      [place1, place2].each do |place|
        I18n.with_locale(:en) { place.set_data_hash(data_hash: { 'name' => shared_title }, partial_update: true) }
      end

      duplicates = place1.reload.find_duplicates

      # the modules match per translation, so both report the pair once per shared locale - four
      # reports that have to collapse to one row per method
      assert_equal 2, duplicates.size
      assert_equal duplicates.size, duplicates.uniq { |t| [t[:thing_duplicate_id], t[:method]] }.size

      place1.create_duplicate_candidates
      rows = place1.duplicate_candidates.reload.select { |c| c.duplicate_id == place2.id }

      assert_equal ['name_similarity', 'only_title'], rows.map(&:duplicate_method).sort
    end

    test 'a duplicate destroyed mid-recalculation is skipped instead of aborting the run' do
      place1, place2 = create_place_pair_with_equal_titles
      destroyed = [{ thing_duplicate_id: SecureRandom.uuid, method: 'only_title', score: 83 }]

      # a long dc:duplicates run reads a pair and inserts it minutes later, by which time an import
      # or a cleanup may have destroyed either end - the foreign keys reject the row for the gone one
      place1.stub(:find_duplicates, destroyed) do
        assert_equal 0, place1.create_duplicate_candidates
      end

      # and the transaction takes the deletes back with it, so what it already had survives
      assert_equal [place2.id], place1.duplicate_candidates.reload.pluck(:duplicate_id).uniq
    end

    test 'recalculation still removes automatic candidates that no longer match' do
      place1, place2 = create_place_pair_with_equal_titles

      assert_equal [place2.id], place1.duplicate_candidates.reload.pluck(:duplicate_id).uniq

      place2.set_data_hash(data_hash: { 'name' => "Something Else #{SecureRandom.hex(4)}" }, partial_update: true)

      # the rake tasks count what this returns, so the branch that only deletes has to report 0
      assert_equal 0, place1.create_duplicate_candidates
      assert_empty place1.duplicate_candidates.reload
    end

    # Counts the SELECTs a block triggers, ignoring schema lookups and query-cache hits.
    def count_queries(&)
      count = 0
      subscriber = ActiveSupport::Notifications.subscribe('sql.active_record') do |_, _, _, _, payload|
        count += 1 unless payload[:name] == 'SCHEMA' || payload[:cached]
      end

      DataCycleCore::Thing.uncached(&)

      count
    ensure
      ActiveSupport::Notifications.unsubscribe(subscriber)
    end

    test 'duplicate_candidates_for_api does not query per candidate' do
      place = DataCycleCore::TestPreparations.create_content(template_name: 'Örtlichkeit', data_hash: { name: "Api Original #{SecureRandom.hex(4)}" })

      mark_manual = lambda { |count|
        count.times do |i|
          duplicate = DataCycleCore::TestPreparations.create_content(template_name: 'Örtlichkeit', data_hash: { name: "Api Duplicate #{i} #{SecureRandom.hex(4)}" })
          DataCycleCore::ThingDuplicate.create!(thing_id: place.id, thing_duplicate_id: duplicate.id, method: 'manual', score: 90 - i)
        end
      }

      mark_manual.call(1)
      # warm up first: the initial call resolves things that are then cached for the whole process
      # (template lookups, feature configuration), which cost two queries in a fresh process and none
      # afterwards - measuring without this compares a cold call against a warm one
      place.duplicate_candidates_for_api

      one = count_queries { place.duplicate_candidates.reload.load && place.duplicate_candidates_for_api }

      mark_manual.call(3)
      four = count_queries { place.duplicate_candidates.reload.load && place.duplicate_candidates_for_api }

      assert_equal 4, place.duplicate_candidates.reload.size
      # the name of a duplicate comes from the translations table: without preloading it, each
      # additional candidate would add a query of its own. Asserted as "not more" rather than "equal",
      # so a one-time lookup that lands in the first block cannot turn this into a false alarm
      assert_operator four, :<=, one, "#{four - one} additional queries for three additional candidates"
    end

    test 'the manual duplicate method resolves to a labelled module' do
      candidate_module = DataCycleCore::Utility::DuplicateCandidate::Base.by_identifier('manual')

      assert_equal DataCycleCore::Utility::DuplicateCandidate::Manual, candidate_module
      assert_equal 'manual', candidate_module.identifier
      assert_predicate candidate_module.model_name.human(count: 1, locale: :de), :present?
      assert_predicate candidate_module.model_name.human(count: 1, locale: :en), :present?
      # never participates in automatic detection
      assert_empty Array.wrap(candidate_module.duplicates(content: nil))
    end

    test 'the backend method filter offers the manual method as well' do
      selectable = DataCycleCore::Feature::DuplicateCandidate.selectable_rules

      # the filter select is built from selectable_rules; without the reserved methods the backend
      # could not filter for what the API and the backend itself write as `manual`
      assert_includes selectable, DataCycleCore::Utility::DuplicateCandidate::Manual
      assert_empty DataCycleCore::Feature::DuplicateCandidate.available_rules - selectable
      assert_equal selectable.uniq, selectable
    end

    test 'merge_inline? is limited by the number of linked contents' do
      previous_limit = DataCycleCore.features[:duplicate_candidate][:inline_merge_limit]
      image = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: { name: 'Test Bild 1' })
      DataCycleCore::TestPreparations.create_content(template_name: 'POI', data_hash: { name: 'Test POI 1', image: [image.id] })

      assert DataCycleCore::Feature::DuplicateCandidate.merge_inline?(image)

      DataCycleCore.features[:duplicate_candidate][:inline_merge_limit] = 0
      DataCycleCore::Feature::DuplicateCandidate.reload

      assert_not DataCycleCore::Feature::DuplicateCandidate.merge_inline?(image)

      DataCycleCore.features[:duplicate_candidate][:inline_merge_limit] = nil
      DataCycleCore::Feature::DuplicateCandidate.reload

      assert_not DataCycleCore::Feature::DuplicateCandidate.merge_inline?(image)
    ensure
      DataCycleCore.features[:duplicate_candidate][:inline_merge_limit] = previous_limit
      DataCycleCore::Feature::DuplicateCandidate.reload
    end

    test 'merge_inline? also counts the embedded children destroyed with the duplicate' do
      previous_limit = DataCycleCore.features[:duplicate_candidate][:inline_merge_limit]
      # nothing links to this POI, so destroying its embedded children is the merge's only work
      poi = DataCycleCore::TestPreparations.create_content(
        template_name: 'POI',
        data_hash: { name: 'Test POI Embedded', additional_information: [{ name: 'Info 1' }, { name: 'Info 2' }] }
      )

      assert_equal 2, poi.additional_information.size
      assert_empty poi.content_content_b, 'precondition: nothing may link to the duplicate'

      DataCycleCore.features[:duplicate_candidate][:inline_merge_limit] = 2
      DataCycleCore::Feature::DuplicateCandidate.reload

      assert DataCycleCore::Feature::DuplicateCandidate.merge_inline?(poi)

      DataCycleCore.features[:duplicate_candidate][:inline_merge_limit] = 1
      DataCycleCore::Feature::DuplicateCandidate.reload

      assert_not DataCycleCore::Feature::DuplicateCandidate.merge_inline?(poi)
    ensure
      DataCycleCore.features[:duplicate_candidate][:inline_merge_limit] = previous_limit
      DataCycleCore::Feature::DuplicateCandidate.reload
    end

    test 'merge_duplicate refuses pairs that cannot be merged' do
      image = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: { name: 'Test Bild 1' })
      poi = DataCycleCore::TestPreparations.create_content(template_name: 'POI', data_hash: { name: 'Test POI 1' })

      assert_not DataCycleCore::Feature::DuplicateCandidate.merge_duplicate(image, nil)
      assert_not DataCycleCore::Feature::DuplicateCandidate.merge_duplicate(nil, image)
      assert_not DataCycleCore::Feature::DuplicateCandidate.merge_duplicate(image, image)
      assert_not DataCycleCore::Feature::DuplicateCandidate.merge_duplicate(image, poi)

      assert_predicate DataCycleCore::Thing.find_by(id: image.id), :present?
      assert_predicate DataCycleCore::Thing.find_by(id: poi.id), :present?
    end

    test 'a locked content stops the merge and the rest is merged on the next attempt' do
      assert_predicate DataCycleCore::Feature::ContentLock, :enabled?

      user = DataCycleCore::User.find_by(email: 'tester@datacycle.at')
      original = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: { name: 'Merge Ziel' })
      duplicate = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: { name: 'Merge Duplikat' })
      locked = DataCycleCore::TestPreparations.create_content(template_name: 'POI', data_hash: { name: 'Gesperrter POI', image: [duplicate.id] })
      unlocked = DataCycleCore::TestPreparations.create_content(template_name: 'POI', data_hash: { name: 'Offener POI', image: [duplicate.id] })

      DataCycleCore::ContentLock.create!(activitiable: locked, user:, activity_type: 'content_lock')

      assert_predicate locked.reload, :locked?

      assert_raises DataCycleCore::Feature::DuplicateCandidate::Merge::LockedContentsError do
        DataCycleCore::Feature::DuplicateCandidate.merge_duplicate(original, duplicate, current_user: user)
      end

      # the unlocked link was moved, the locked one stayed and the duplicate is still there
      assert_equal [original.id], unlocked.image.reload.pluck(:id)
      assert_equal [duplicate.id], locked.image.reload.pluck(:id)
      assert_predicate DataCycleCore::Thing.find_by(id: duplicate.id), :present?

      locked.lock.destroy

      # merging is idempotent => the next attempt moves whatever is left over
      assert DataCycleCore::Feature::DuplicateCandidate.merge_duplicate(
        DataCycleCore::Thing.find(original.id),
        DataCycleCore::Thing.find(duplicate.id),
        current_user: user
      )

      assert_equal [original.id], locked.image.reload.pluck(:id)
      assert_nil DataCycleCore::Thing.find_by(id: duplicate.id)
    end

    test 'duplicates marked as false_positive are not shown as duplicates' do
      image1 = upload_image('test_rgb.jpeg')

      assert_predicate image1.thumb_preview, :present?
      content1 = create_content('Bild', { name: 'Test Bild 1', asset: image1.id })

      image2 = upload_image('test_rgb.png')

      assert_predicate image2.thumb_preview, :present?
      content2 = create_content('Bild', { name: 'Test Bild 2', asset: image2.id })

      assert_equal 1, content1.duplicate_candidates.size
      assert_equal 1, content2.duplicate_candidates.size

      content2.duplicate_candidates
        .where(duplicate_id: content1.id)
        .thing_duplicates
        .update_all(false_positive: true)

      assert_empty content1.duplicate_candidates.reload
      assert_empty content2.duplicate_candidates.reload
    end

    test 'duplicates from different external_source get merged correctly' do
      external_source_f = DataCycleCore::ExternalSystem.find_by(identifier: 'local-system')
      external_key_f = SecureRandom.uuid
      external_source_oa = DataCycleCore::ExternalSystem.find_by(identifier: 'remote-system')
      external_key_oa = SecureRandom.uuid
      external_source_v = DataCycleCore::ExternalSystem.find_by(identifier: 'remote-system-2')
      external_key_v = SecureRandom.uuid
      external_source_m = DataCycleCore::ExternalSystem.find_by(identifier: 'remote-system-3')
      external_key_m = SecureRandom.uuid
      external_source_hrs = DataCycleCore::ExternalSystem.find_by(identifier: 'remote-system-4')
      external_key_hrs = SecureRandom.uuid

      image_f = create_content('Bild', { name: 'Test Bild 1' })
      image_f.update_columns(external_source_id: external_source_f.id, external_key: external_key_f)
      image_f.external_system_syncs.find_or_create_by!(external_system_id: external_source_v.id, external_key: external_key_v, sync_type: 'duplicate')

      image_oa = create_content('Bild', { name: 'Test Bild 2' })
      image_oa.update_columns(external_source_id: external_source_oa.id, external_key: external_key_oa)
      image_oa.external_system_syncs.find_or_create_by!(external_system_id: external_source_v.id, external_key: external_key_v, sync_type: 'duplicate')
      image_oa.external_system_syncs.find_or_create_by!(external_system_id: external_source_m.id, external_key: external_key_m, sync_type: 'link')
      image_oa.external_system_syncs.find_or_create_by!(external_system_id: external_source_hrs.id, external_key: external_key_hrs, sync_type: 'export')
      image_oa.external_system_syncs.find_or_create_by!(external_system_id: external_source_f.id, external_key: external_key_f, sync_type: 'duplicate')
      image_oa.external_system_syncs.find_or_create_by!(external_system_id: external_source_f.id, external_key: external_key_v, sync_type: 'link')

      image_f.merge_with_duplicate(image_oa)
      perform_enqueued_jobs

      assert_nil DataCycleCore::Thing.find_by(id: image_oa.id)

      assert_equal external_source_f.id, image_f.external_source.id
      assert_equal 5, image_f.external_system_syncs.size
      assert_equal 1, image_f.external_system_syncs.where(sync_type: 'import').size
      assert_equal 4, image_f.external_system_syncs.where(sync_type: 'duplicate').size
      assert_equal 0, image_f.external_system_syncs.where(sync_type: 'link').size
      assert_equal 0, image_f.external_system_syncs.where(sync_type: 'export').size
    end

    test 'find duplicates for Örtlichkeit after creation' do
      content1 = DataCycleCore::DataHashService.create_internal_object('Örtlichkeit', { datahash: { name: 'Test Örtlichkeit 1' } }, nil)
      content2 = DataCycleCore::DataHashService.create_internal_object('Örtlichkeit', { datahash: { name: 'Test Örtlichkeit 1' } }, nil)
      perform_enqueued_jobs

      assert_equal 2, content1.duplicate_candidates.size
      assert_equal 2, content2.duplicate_candidates.size
    end

    test 'find duplicates for Örtlichkeit after template_name change' do
      perform_enqueued_jobs do
        content1 = DataCycleCore::DataHashService.create_internal_object('Örtlichkeit', { datahash: { name: 'Test Örtlichkeit 1' } }, nil)
        content2 = DataCycleCore::DataHashService.create_internal_object('POI', { datahash: { name: 'Test Örtlichkeit 1' } }, nil)

        assert_empty content1.duplicate_candidates
        assert_empty content2.duplicate_candidates

        content2.update!(template_name: 'Örtlichkeit')

        assert_equal 2, content1.duplicate_candidates.size
        assert_equal 2, content2.duplicate_candidates.size
      end
    end

    test 'find duplicates for Örtlichkeit after update of name' do
      content1 = DataCycleCore::DataHashService.create_internal_object('Örtlichkeit', { datahash: { name: 'Test Örtlichkeit 1' } }, nil)
      content2 = DataCycleCore::DataHashService.create_internal_object('Örtlichkeit', { datahash: { name: 'Test Örtlichkeit 1' } }, nil)
      perform_enqueued_jobs

      assert_equal 2, content1.duplicate_candidates.size
      assert_equal 2, content2.duplicate_candidates.size

      content1.set_data_hash(data_hash: { name: 'Test Örtlichkeit 2' })
      perform_enqueued_jobs

      assert_equal 1, content1.duplicate_candidates.size
      assert_equal 1, content2.duplicate_candidates.size

      content1.set_data_hash(data_hash: { name: 'Örtlichkeit 2' })
      perform_enqueued_jobs

      assert_empty content1.duplicate_candidates
      assert_empty content2.duplicate_candidates
    end

    test 'mark Örtlichkeit as false positive marks all methods correctly' do
      content1 = DataCycleCore::DataHashService.create_internal_object('Örtlichkeit', { datahash: { name: 'Test Örtlichkeit 1' } }, nil)
      content2 = DataCycleCore::DataHashService.create_internal_object('Örtlichkeit', { datahash: { name: 'Test Örtlichkeit 1' } }, nil)
      perform_enqueued_jobs

      assert_equal 2, content1.duplicate_candidates.size
      assert_equal 2, content2.duplicate_candidates.size

      content1.mark_duplicate_as_false_positive(content2)

      assert_empty content1.duplicate_candidates
      assert_empty content2.duplicate_candidates
    end

    test 'mark Örtlichkeit as false positive with new method added after' do
      place_template = DataCycleCore::ThingTemplate.find_by(template_name: 'Örtlichkeit')
      updates = [{ template_name: place_template.template_name, schema: place_template.schema.deep_merge('features' => { 'duplicate_candidate' => { 'allowed' => true, 'module' => ['OnlyTitle'] } }) }]
      DataCycleCore::ThingTemplate.upsert_all(updates, unique_by: :template_name)

      content1 = DataCycleCore::DataHashService.create_internal_object('Örtlichkeit', { datahash: { name: 'Test Örtlichkeit 1' } }, nil)
      content2 = DataCycleCore::DataHashService.create_internal_object('Örtlichkeit', { datahash: { name: 'Test Örtlichkeit 1' } }, nil)
      perform_enqueued_jobs

      assert_equal 1, content1.duplicate_candidates.size
      assert_equal 1, content2.duplicate_candidates.size

      content1.mark_duplicate_as_false_positive(content2)

      assert_empty content1.duplicate_candidates
      assert_empty content2.duplicate_candidates

      updates = [{ template_name: place_template.template_name, schema: place_template.schema.deep_merge('features' => { 'duplicate_candidate' => { 'allowed' => true, 'module' => ['OnlyTitle', 'NameSimilarity'] } }) }]
      DataCycleCore::ThingTemplate.upsert_all(updates, unique_by: :template_name)

      content1.set_data_hash(data_hash: { name: 'Test Örtlichkeit 2' })
      perform_enqueued_jobs

      assert_empty content1.duplicate_candidates
      assert_empty content2.duplicate_candidates
    end
  end
end
