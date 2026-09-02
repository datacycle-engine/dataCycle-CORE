# frozen_string_literal: true

# [#50666] One-time rename of the download-step priority stored in the mongo dumps.
#
# A download step's configured `priority` used to be written into the dump under a bare `priority`
# key, and item_allowed? read it back from there to decide whether the step may overwrite a stored
# item. That key is not ours alone: source payloads legitimately ship a field called `priority`
# (Intermaps SRM sends a display-order integer on every object). Since b01a09cfd an item carrying
# any `priority` is blocked from being rewritten by an unprioritised step, so every such item froze
# permanently - seen_at kept advancing while the dump never changed again.
#
# The key is now namespaced as `dc_step_priority`. This migration moves the values we wrote to the
# new key, so genuinely prioritised steps keep their claim instead of losing it and taking one
# clobbering cycle. Source-owned `priority` fields are deliberately left in place; they are payload
# data and are simply no longer consulted.
#
# Only the collections DataCycle actually wrote a priority into are touched: the target of a
# download step that configures `priority:`. Nothing else ever wrote the key. In particular the
# concept strategies did not, despite their pipelines listing one: a bare number in `$project` is
# an inclusion flag, not a literal, so `'data.priority' => 5` only ever copied a *source* field of
# that name through and never stamped the default (the second defect fixed alongside this). Any
# bare `priority` sitting in the target of an unprioritised concept step is therefore payload data,
# and renaming it would re-create the very freeze this migration exists to undo.
#
# A collection written by both a prioritised and an unprioritised step would be ambiguous, but that
# combination is exactly what the priority mechanism exists to prevent, so it should not occur. The
# per-collection counts are logged to make any surprise visible.
#
# Idempotent: only documents that still have the old key and not the new one are updated. An
# unreachable external system aborts the run rather than being skipped - a half-applied rename that
# records itself as done would cost the prioritised steps their claim, and re-running is free.
class NamespaceDownloadStepPriorityInMongoDumps < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  OLD_KEY = 'priority'
  NEW_KEY = DataCycleCore::Generic::Common::Extensions::DumpKeyPolicy::STEP_PRIORITY_KEY

  def up
    rename_all(from: OLD_KEY, to: NEW_KEY)
  end

  def down
    rename_all(from: NEW_KEY, to: OLD_KEY)
  end

  private

  def rename_all(from:, to:)
    DataCycleCore::ExternalSystem.find_each do |external_system|
      source_types = prioritised_source_types(external_system)
      next if source_types.blank?

      locales = locales_for(external_system)

      source_types.each do |source_type|
        rename_in(external_system:, source_type:, locales:, from:, to:)
      end
    rescue Mongo::Error, Mongoid::Errors::MongoidError => e
      raise "#{self.class.name}: #{external_system.identifier} could not be reached (#{e.class}: #{e.message}). " \
            'Restore the connection and run the migration again - it is idempotent.'
    end
  end

  def rename_in(external_system:, source_type:, locales:, from:, to:)
    external_system.collection(source_type) do |collection|
      locales.each do |locale|
        old_path = "dump.#{locale}.#{from}"
        new_path = "dump.#{locale}.#{to}"

        result = collection.update_many(
          { old_path => { '$exists' => true }, new_path => { '$exists' => false } },
          { '$rename' => { old_path => new_path } }
        )

        next if result.modified_count.zero?

        say "#{external_system.identifier} / #{source_type} [#{locale}]: renamed #{result.modified_count}"
      end
    end
  end

  # A step's target collection is its source_type. Steps without one write no dump at all.
  def prioritised_source_types(external_system)
    Array.wrap(external_system.download_config&.values)
      .select { |step| step['priority'].present? }
      .flat_map { |step| Array.wrap(step['source_type']) }
      .filter_map(&:presence)
      .uniq
  end

  # Renaming a locale that was never dumped is a no-op, so err on the side of covering more.
  def locales_for(external_system)
    (Array.wrap(external_system.locales) | I18n.available_locales.map(&:to_s)).compact_blank
  end
end
