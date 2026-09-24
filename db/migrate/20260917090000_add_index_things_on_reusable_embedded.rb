# frozen_string_literal: true

# Feature::ReusableEmbedded.reusable_only filters the object browser on
# `content_type = 'embedded' AND things.metadata ->> 'reusable' = 'true'`, once per keystroke and
# once more for the count. Flagged embedded are a small fraction of the embedded rows (opening
# hours, offers, images run to millions), so without this the filter reads every row of the
# allowed templates.
class AddIndexThingsOnReusableEmbedded < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :things, "(metadata ->> 'reusable')",
              where: "content_type = 'embedded'",
              name: 'index_things_on_reusable_embedded',
              algorithm: :concurrently,
              if_not_exists: true
  end
end
