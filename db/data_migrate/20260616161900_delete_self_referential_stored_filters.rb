# frozen_string_literal: true

class DeleteSelfReferentialStoredFilters < ActiveRecord::Migration[8.0]
  # A self-referential stored filter (its relation/filter_ids references lead back to itself, directly
  # or transitively) resolves to itself and can never be executed (infinite recursion). New ones are
  # rejected on save (DataCycleCore::StoredFilter#must_not_reference_itself); delete the ones that
  # already exist, since they do not work anyway. Covers named and unnamed filters.
  #
  # Runs before CreateSqlRepresentationsOfAlreadyExistingStoredFilters (20260616161945) so the
  # representation build never encounters a self-referential filter (and never trips its recursion).
  def up
    # Detect first, delete after: a transitive cycle (A -> B -> A) is only detectable while every
    # member still exists, so deleting one mid-scan would hide the rest. Collect all matches over the
    # intact graph, then remove them.
    #
    # Only filters that reference at least one other filter can start a cycle, so restrict the
    # (per-filter, multi-query) transitive check to those candidates via a jsonb containment check.
    contains = DataCycleCore::StoredFilter::SELF_REFERENCE_FILTER_TYPES.map do |type|
      "#{DataCycleCore::StoredFilter.connection.quote([{ 't' => type }].to_json)}::jsonb"
    end
    candidates = DataCycleCore::StoredFilter.where(Arel.sql("parameters @> ANY(ARRAY[#{contains.join(', ')}])"))

    self_referential = candidates.find_each.select(&:self_referential?)

    # destroy (not delete_all) so after_destroy drops any leftover SQL representation.
    self_referential.each(&:destroy!)
  end

  def down
    # deleting broken data is irreversible
  end
end
