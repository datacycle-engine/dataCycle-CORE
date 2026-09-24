# frozen_string_literal: true

# Five indexes on searches that no read path can use. Not "unused by whichever fulltext
# implementation happens to be enabled" -- neither Filter::Common::Fulltext implementation, nor
# any other query, issues an operator that reaches them:
#
# - words_idx (on full_text) and classification_string_idx: those columns appear only inside
#   similarity() in Filter::Sortable#sort_legacy_fulltext_search's ORDER BY. A trigram GIN index
#   serves ILIKE and `%`, not the similarity() function, so that ORDER BY plans as a Seq Scan
#   feeding a full sort, with no index access at all.
# - validity_period_idx: nothing reads searches.validity_period at all.
#   Filter::Common::Date#in_validity_period filters things.validity_range instead.
# - index_searches_on_classification_aliases_mapping and ..._ancestors_mapping: both columns are
#   written by Content::UpdateSearch and never read back by any query.
#
# index_searches_on_advanced_attributes was in this list until
# Filter::Common::Advanced#advanced_classification_contains rewrote the :equals comparison as
# `advanced_attributes @> {"<path>": ["<id>"]}`, which that index does serve -- so it stays, and
# earns its keep at 427 ms -> 0.12 ms on 612k rows.
#
# Production agrees, on statistics that have never been reset: all five report idx_scan = 0, while
# index_searches_on_content_data_id_and_locale on the same table reports 154,115,637,820.
#
# The 389 MB they occupy is the smaller half of the cost. UpdateSearch rewrites all five of these
# columns on every content save, so every save maintains all five indexes and WAL-logs the result.
# Measured on all_text_idx and index_searches_on_words -- 409 MB of GIN over the same table -- a
# 5,000 row update took 595 ms and 65 MB of WAL without them against 2,436 ms and 578 MB with
# them: 4.1x the time and 8.9x the WAL, which also lands on replication and PITR replay. words_idx
# is trigram GIN over the same long text as all_text_idx, so it carries a comparable share; the
# uuid[] and gist indexes dropped here are cheaper.
#
# all_text_idx and index_searches_on_words are deliberately kept: legacy_fulltext_search does
# reach both, as a single BitmapOr, so they belong to
# Feature::TsQueryFulltextSearch::LEGACY_ONLY_INDEXES and dc:features:sync_fulltext_indexes.
class DropUnusedSearchIndexes < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  UNUSED_INDEXES = [
    { name: 'words_idx', column: :full_text, using: :gin, opclass: :gin_trgm_ops },
    { name: 'classification_string_idx', column: :classification_string, using: :gin, opclass: :gin_trgm_ops },
    { name: 'validity_period_idx', column: :validity_period, using: :gist },
    { name: 'index_searches_on_classification_aliases_mapping', column: :classification_aliases_mapping, using: :gin },
    { name: 'index_searches_on_classification_ancestors_mapping', column: :classification_ancestors_mapping, using: :gin }
  ].freeze

  def up
    UNUSED_INDEXES.each do |index|
      remove_index :searches, name: index[:name], algorithm: :concurrently, if_exists: true
    end
  end

  def down
    UNUSED_INDEXES.each do |index|
      add_index :searches, index[:column], **index.except(:column), algorithm: :concurrently, if_not_exists: true
    end
  end
end
