# frozen_string_literal: true

module DataCycleCore
  # The three since-filters the classification_trees endpoints of API v1-v3 and the xml interface
  # offer. Since Redmine #41458 `concepts` and `concept_schemes` carry no deleted_at - a deleted row
  # lives on in Concept::History / ConceptScheme::History - so +deleted_since+ picks a different
  # table rather than widening the live one, which is why the scope is chosen before the filters are
  # applied instead of narrowed afterwards.
  module ConceptSinceFilterConcern
    extend ActiveSupport::Concern

    SINCE_COLUMNS = { modified_since: :updated_at, created_since: :created_at, deleted_since: :deleted_at }.freeze

    private

    # API v1 carries the three filters at the top level, v2 onwards inside +filter+.
    def since_params
      (permitted_params[:filter] || permitted_params).to_h.symbolize_keys.slice(*SINCE_COLUMNS.keys)
    end

    def concept_scheme_scope(since)
      return ConceptScheme::History.where(internal: false) if since[:deleted_since].present?

      ConceptScheme.where(internal: false)
    end

    # Whether the scheme's own concepts are what the request asks for: a deleted-concepts request
    # answers from concept_histories instead, and a deleted scheme has no live concepts left at all.
    def live_concept_scope?(concept_scheme, since)
      since[:deleted_since].blank? && concept_scheme.is_a?(ConceptScheme)
    end

    # The concepts of +concept_scheme+, or the deleted ones it used to hold. concept_scheme_id is a
    # plain column on concept_histories, so a deleted scheme still answers for its deleted concepts,
    # while its live ones went with it through the FK ON DELETE CASCADE on concepts.
    def concept_scope(concept_scheme, since)
      return concept_scheme.concepts if live_concept_scope?(concept_scheme, since)
      return Concept::History.where(concept_scheme_id: concept_scheme.id) if since[:deleted_since].present?

      Concept.none
    end

    # The scope the +strict+ / +classification_id+ modes of API v3 and the xml interface select:
    # +strict+ limits the result to one level - the children of +concept_id+, or the scheme's roots -
    # while +concept_id+ alone returns its whole subtree. Neither applies to a deleted-concepts
    # request, because concept_links and concept_paths go with the concept and leave no tree to
    # navigate.
    def concept_scope_for_mode(concept_scheme, since, concept_id, strict:)
      base = concept_scope(concept_scheme, since)
      return base unless live_concept_scope?(concept_scheme, since)

      if concept_id.present?
        concept = DataCycleCore::Concept.find(concept_id)
        strict ? concept.children : concept.descendants
      elsif strict
        concept_scheme.concepts.roots
      else
        base
      end
    end

    # Each filter orders by the column it filters on. The relation is reordered only once a filter
    # applies, so an unfiltered concept query keeps the order_a of Concept's default scope.
    def apply_since_filters(scope, since)
      table = scope.klass.arel_table
      filters = SINCE_COLUMNS.select { |key, _| since[key].present? }
      return scope if filters.empty?

      filters.reduce(scope.reorder(nil)) do |query, (key, column)|
        query.where(table[column].gteq(Time.zone.parse(since[key]))).order(column)
      end
    end
  end
end
