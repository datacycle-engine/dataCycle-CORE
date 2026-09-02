# frozen_string_literal: true

# Redmine #47172: the CCC read paths (filter/facet counts, detail, API, search) select visible
# mappings only (`hidden = false`). The existing ccc_ca_id_t_id_idx
# (classification_alias_id, thing_id, link_type) can't satisfy that predicate from the index, so a
# count on an alias that has hidden mappings resolves the alias via the index but then heap-fetches
# every row for it just to drop the hidden ones (`Bitmap Heap Scan` -> `Filter: (NOT hidden)`).
#
# Appending `hidden` as a trailing key column keeps the existing (alias, thing, link_type) prefix
# byte-for-byte (so point lookups are unaffected) while making the visible count index-only. It
# replaces the old index rather than adding a second one, so there is no near-duplicate index and
# no net disk cost (a fresh rebuild also reclaims bloat). Built concurrently, mirroring
# 20260508095018_adjust_index_for_facets_endpoint.
class AddHiddenToCccAliasThingIndex < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def up
    add_index :collected_classification_contents, [:classification_alias_id, :thing_id, :link_type, :hidden],
              name: 'ccc_ca_id_t_id_hidden_idx', algorithm: :concurrently, if_not_exists: true
    remove_index :collected_classification_contents, name: 'ccc_ca_id_t_id_idx',
                                                     algorithm: :concurrently, if_exists: true
  end

  def down
    add_index :collected_classification_contents, [:classification_alias_id, :thing_id, :link_type],
              name: 'ccc_ca_id_t_id_idx', algorithm: :concurrently, if_not_exists: true
    remove_index :collected_classification_contents, name: 'ccc_ca_id_t_id_hidden_idx',
                                                     algorithm: :concurrently, if_exists: true
  end
end
