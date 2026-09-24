# frozen_string_literal: true

# [#46710] Clears the `compact` visibility that DataCycleCore.default_classification_visibilities
# handed out before the same commit dropped it from that list. `compact` remains a member of
# ConceptScheme::VISIBILITY_GROUPS[:contents] that the scheme form offers, and nothing distinguishes
# a leftover default from a deliberate choice, so a scheme set to compact since loses it too - the
# one-off cost the ticket accepted.
#
# Written against classification_tree_labels, then ported to ConceptScheme by #41458: under dc:update
# every schema migration precedes the first data migration, so wherever this one is still pending it
# meets the post-cut schema, where the same column lives on concept_schemes. One of the 65 project
# checkouts has it pending; the rest already ran it and never load this file again.
#
# A standalone `rails db:migrate:data` has no such ordering, and pre-cut concept_schemes is a
# trigger-maintained projection of classification_tree_labels - writing to it there would report a
# success the next touch of the tree label overwrites. So the statement names whichever of the two
# owns the column in the schema it finds.
class RemoveCompactFromDefaulClassificationVisibilities < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def up
    table = table_exists?(:classification_tree_labels) ? 'classification_tree_labels' : 'concept_schemes'

    updated = execute(<<~SQL.squish).cmd_tuples
      UPDATE #{table}
      SET visibility = array_remove(visibility, 'compact')
      WHERE visibility @> ARRAY['compact']::varchar[];
    SQL

    say "removed 'compact' from #{updated} #{table} row(s)"
  end

  def down
  end
end
