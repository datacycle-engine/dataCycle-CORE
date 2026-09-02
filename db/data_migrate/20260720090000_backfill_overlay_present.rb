# frozen_string_literal: true

# [#47366] One-time backfill for the overlay_present computed attribute.
#
# overlay_present is a denormalized, advanced-searchable boolean computed from a content's
# overlay attributes (inline *_override / *_add or the legacy overlay relation). It is only
# (re)computed when one of those dependency attributes changes; its default_value (false)
# materializes it for content that never touches an overlay attribute.
#
# Content imported before overlay_present existed therefore keeps the default false even when it
# already carries overlay values - the overlay attributes did not "change" after the attribute
# was introduced, so nothing triggered a recompute. This migration recomputes overlay_present for
# all existing content directly, so the "with/without overlay" filter is accurate for legacy data.
#
# Ships gem-wide but is inert for templates without overlay attributes: the task only touches
# templates that actually declare overlay_present in their computed_property_names.
class BackfillOverlayPresent < ActiveRecord::Migration[8.0]
  # uncomment the following line to disable transactions
  # disable_ddl_transaction!

  def up
    DataCycleCore::RunTaskJob.perform_later('dc:update_data:computed_attributes', [nil, false, 'overlay_present'])
  end

  def down
  end
end
