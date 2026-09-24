# frozen_string_literal: true

# [#41458] Moves stored filters onto the concept filter vocabulary.
#
# A stored filter names the method it runs in `parameters -> 't'` (`{"t": "classification_alias_ids",
# "m": "e", ...}`, the `m` carrying a negation rather than the `t`), and Filter::Common::Classification
# no longer answers to the old names. The same words also key the advanced_filter section of
# features.yml, the role parameters under config/configurations/permissions and the `filter_groups.*`
# translations, which is why they move in one commit - AdvancedFilterByType#include? compares such a
# config key straight against a `t`.
#
# `n` is the label the dashboard prints on the filter chip. Usually it holds a concept scheme's name
# ("Inhaltstypen"), but param_from_definition falls back to `t.capitalize`, so vcloud-dev has 64 chips
# reading "Classification_tree_ids" - those follow their `t`.
#
# Rewritten on `parameters::text` rather than per array element: a `union` filter nests further filters
# inside its own `v` (Type::StoredFilter::Parameters.transform_union), and jsonb renders its keys
# canonically as `"t": "..."`, so one pass over the document reaches every depth.
class RenameClassificationFiltersToConceptFilters < ActiveRecord::Migration[8.0]
  # `with_classification_alias_ids_without_recursion` is the one name that had no working
  # implementation to rename: pre-cut it was a stub raising DeprecatedMethodError, and its own
  # deprecation note named `classification_alias_ids_without_subtree` as the replacement. It is
  # renamed all the same, because apply_single_filter! is a `return unless query.respond_to?(t)` -
  # dropping the name would turn a stored filter that raised into one that quietly serves an
  # unfiltered superset.
  FILTER_RENAMES = {
    'with_classification_alias_ids_without_recursion' => 'concept_ids_without_subtree',
    'classification_alias_ids_without_subtree_with_related' => 'concept_ids_without_subtree_with_related',
    'classification_alias_ids_without_subtree' => 'concept_ids_without_subtree',
    'classification_alias_ids_with_subtree' => 'concept_ids_with_subtree',
    'classification_alias_ids_related' => 'concept_ids_related',
    'classification_alias_ids' => 'concept_ids',
    'classification_tree_ids' => 'concept_scheme_ids'
  }.freeze

  NAME_KEYS = ['t', 'q'].freeze
  NEGATION_PREFIXES = ['', 'not_'].freeze

  def up
    rewritten = execute(rewrite_sql(FILTER_RENAMES)).cmd_tuples
    say "rewrote the filter vocabulary in #{rewritten} collection(s)"

    resync_sql_representations
  end

  def down
    raise ActiveRecord::IrreversibleMigration,
          'the schema migration this follows (ReplaceClassificationsWithConcepts) is irreversible; roll back from the deploy dump'
  end

  private

  # The 40 of 52 generated stored_filter_<uuid>() functions on vcloud-dev that still select from
  # collected_classification_contents. StoredFilter#sync_sql_representation! rebuilds the body from
  # the filter chain, so it has to run after the `t` values above are in place.
  def resync_sql_representations
    scope = DataCycleCore::StoredFilter.where.not(name: nil)

    say_with_time "rebuilding #{scope.count} SQL representation(s)" do
      scope.find_each(&:sync_sql_representation!)
    end
  end

  # @param renames [Hash{String => String}] old filter name => new filter name
  def rewrite_sql(renames)
    pairs = renames.flat_map { |old, new| rename_pairs(old, new) }

    <<~SQL.squish
      UPDATE collections
      SET parameters = (#{pairs.reduce('parameters::text') { |sql, (from, to)| "REPLACE(#{sql}, #{connection.quote(from)}, #{connection.quote(to)})" }})::jsonb
      WHERE #{pairs.map { |from, _| "parameters::text LIKE #{connection.quote("%#{from}%")}" }.join(' OR ')}
    SQL
  end

  # Anchored on the key so a filter *value* spelling one of these names cannot be rewritten. `q` names
  # the advanced type of an `advanced_attributes` filter (`{"t": "advanced_attributes", "q":
  # "classification_alias_ids"}`), which dispatches to Filter::Common::Advanced by the same word.
  #
  # The closing quote is part of the needle, so `"t": "classification_alias_ids"` cannot match inside
  # `"t": "classification_alias_ids_with_subtree"` and the order of the REPLACE chain is free.
  def rename_pairs(old, new)
    NEGATION_PREFIXES.flat_map do |prefix|
      NAME_KEYS.map { |key| [%("#{key}": "#{prefix}#{old}"), %("#{key}": "#{prefix}#{new}")] } +
        [[%("n": "#{(prefix + old).capitalize}"), %("n": "#{(prefix + new).capitalize}")]]
    end
  end
end
