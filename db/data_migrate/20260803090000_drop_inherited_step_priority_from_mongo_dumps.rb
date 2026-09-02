# frozen_string_literal: true

# [#50666] One-time removal of step-priority claims that no step writing the collection could have made.
#
# The eight payload-side keys stripped by DumpKeyPolicy#strip_internal_keys! heal on their own: the
# next download rewrites the dump without them. STEP_PRIORITY_KEY cannot, and not by accident of
# ordering - item_allowed? reads the *stored* dump and `next`s, so an item that already carries a
# foreign claim is never written again and the strip never gets a chance to land. Permanent freeze,
# seen_at still advancing over the touch path: the very signature this ticket is about.
#
# Such claims got there without a step putting them there. A whole-dump copy step (DownloadDataFromData
# without a data_path, DownloadConceptTranslations) projects `'data' => "$dump.<locale>"` complete,
# so it used to carry the *source* collection's claim into its own target; from the second run on
# the step could no longer beat what it had written itself. Measured over every project config: imx has
# this 35 times in 4 installations, where collect_pois / collect_accommodations / collect_gastros /
# collect_conventions read the prioritised `places` and are frozen out of their own targets today.
#
# Two bounds, both derived from the configs rather than named per connector, so this covers whichever
# ones happen to be installed and needs no revisit when a step gains or loses a priority:
#
# - Only a collection no step writes a `priority:` into. One written by a prioritised *and* an
#   unprioritised step keeps its claim: the two are indistinguishable by then, and dropping would
#   cost the legitimate one its protection.
# - Only a claim stronger than DEFAULT_STEP_PRIORITY, which is the only kind that can freeze
#   anything: every step writing such a collection runs at the default, and `5 <= 5` still passes.
#   The concept strategies stamp exactly that default on what they write (with_default_step_priority)
#   while configuring no priority of their own, so a blanket drop would clear a value props_from_config
#   writes straight back and rewrite every concept dump - the one thing !241 was shaped to avoid.
#   `$lt` never matches across BSON types, so a non-numeric value stays; stored_step_priority reads
#   one as no claim regardless.
#
# No rewrite storm follows: this is a raw driver update, so it bumps no mongo updated_at and the items
# do not match with_updated_since_filter on the next import. Idempotent, and irreversible - the dropped
# values are unrecoverable, but the step that owns the collection re-stamps its own claim on the next
# download anyway.
class DropInheritedStepPriorityFromMongoDumps < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  KEY = DataCycleCore::Generic::Common::Extensions::DumpKeyPolicy::STEP_PRIORITY_KEY
  NON_LOCALE_DUMP_KEYS = ['included', 'classifications'].freeze # download_all stores these beside the locales
  DEFAULT_STEP_PRIORITY = DataCycleCore::Generic::Common::Extensions::DumpKeyPolicy::DEFAULT_STEP_PRIORITY

  def up
    DataCycleCore::ExternalSystem.find_each do |external_system|
      claimable = claimable_source_types(external_system)

      collection_names(external_system).each do |collection_name|
        next if claimable.include?(collection_name)

        drop_claims_in(external_system:, collection_name:)
      end
    rescue Mongo::Error, Mongoid::Errors::MongoidError => e
      raise "#{self.class.name}: #{external_system.identifier} could not be reached (#{e.class}: #{e.message}). " \
            'Restore the connection and run the migration again - it is idempotent.'
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration,
          "dropped #{KEY} values are unrecoverable; the step owning the collection re-stamps its claim on the next download"
  end

  private

  # Says the collection before scanning it: reporting only what it drops makes a long run that drops
  # nothing indistinguishable from a hang, and the scan is unindexed.
  def drop_claims_in(external_system:, collection_name:)
    external_system.collection(collection_name) do |collection|
      say "#{external_system.identifier} / #{collection_name}: scanning #{collection.estimated_document_count} document(s)"

      locales_in(collection).each do |locale|
        path = "dump.#{locale}.#{KEY}"

        result = collection.update_many({ path => { '$lt' => DEFAULT_STEP_PRIORITY } }, { '$unset' => { path => '' } })
        next if result.modified_count.zero?

        say "#{external_system.identifier} / #{collection_name} [#{locale}]: dropped #{result.modified_count}"
      end
    end
  end

  # A step's target collection is its source_type (GenericObject builds the persistence context from
  # it verbatim); steps without one write no dump at all. Wrapped because Import#relevant_steps_for
  # reads it as one-or-many, and a miss here drops exactly the claims the first bound exists to keep.
  def claimable_source_types(external_system)
    Array.wrap(external_system.download_config&.values)
      .select { |step| step['priority'].present? }
      .flat_map { |step| Array.wrap(step['source_type']) }
      .filter_map(&:presence)
      .uniq
  end

  # Every collection that exists, not only the configured source_types: a claim reached a collection
  # no step claims in, so the config is not the authority on where to look. A collection holding no
  # dumps at all costs one no-op.
  def collection_names(external_system)
    external_system.collections.to_h.keys.map(&:to_s)
  end

  # Read off the dumps rather than out of the config, which lists the locales a step downloads today:
  # a dump can carry one the system has since dropped, and re-adding it would bring the freeze back.
  # The aggregation yields every top-level dump key, and the only two that are not locales are the ones
  # download_all stores beside them - dropping those saves a no-op update_many each.
  def locales_in(collection)
    pipeline = [
      { '$match' => { 'dump' => { '$type' => 'object' } } },
      { '$project' => { 'l' => { '$objectToArray' => '$dump' } } },
      { '$unwind' => '$l' },
      { '$group' => { '_id' => '$l.k' } }
    ]

    collection.aggregate(pipeline).pluck('_id').compact_blank - NON_LOCALE_DUMP_KEYS
  end
end
