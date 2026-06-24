# frozen_string_literal: true

module DataCycleCore
  # Mögliche Filter-Parameter: c, t, v, m, n, q
  #
  # c => one of 'd', 'a', 'p', 'u', 'uf'                | für 'default', 'advanced', 'permanent advanced', 'user', 'user forced'
  #
  # t => String                                         | der Filtertyp (die Methode, die auf die Query ausgeführt wird, z.B. 'classification_alias_ids')
  #
  # v => String, Array, Hash                            | der übergebene Wert für die Filtermethode (z.B. ['a9b25ff1-5af2-4f21-b61e-408812e14b0d'])
  #
  # m => 'i', 'e', 'g', 'l', 'u', 'n', 's', 'b', 'p'    | Filtermethode, 'include', 'exclude', 'greater', 'lower', 'neutral', 'like', 'notLike', 'blank', 'present'
  #
  # n => String                                         | das Filterlabel (z.B. 'Inhaltspools')
  #
  # q => String (Optional)                              | Ein spezifischer Query-Pfad für das Attribut (z.B. metadata ->> 'width') || type
  class StoredFilter < Collection
    include StoredFilterExtensions::Cachable
    include StoredFilterExtensions::SortParamTransformations
    include StoredFilterExtensions::FilterParamsTransformations
    include StoredFilterExtensions::FilterParamsHashParser

    attribute :parameters, :'stored_filter/parameters'

    attr_accessor :query, :include_embedded

    API_V4_TYPE = 'dc:DynamicCollection'
    KEYS_FOR_TYPE_EQUALITY = ['t', 'c', 'n', 'q'].freeze
    # Filter parameter types whose value (`v`) references other stored filters by id. Following these
    # references back to the filter itself (directly or transitively) makes it resolve to itself, which
    # cannot be executed (infinite recursion), so such filters are rejected (see #self_referential?).
    SELF_REFERENCE_FILTER_TYPES = [
      'related_to', 'not_related_to',
      'relation_filter', 'not_relation_filter', 'relation_filter_inv', 'not_relation_filter_inv',
      'filter_ids', 'not_filter_ids',
      'union_filter_ids', 'not_union_filter_ids'
    ].freeze

    # Only validate when the parameters actually changed: a self-reference can only live in
    # `parameters`, so re-scanning on unrelated updates (e.g. a name change) would needlessly cost
    # performance on every stored-filter save.
    validate :must_not_reference_itself, if: :parameters_changed?

    after_destroy :drop_sql_representation!
    after_save :sync_sql_representation!, if: :sql_representation_update_needed?

    # Return the list of thing ids that match this stored filter.
    def thing_ids
      clear_thing_cache! if parameters_changed? && !new_record?
      @thing_ids ||= things(skip_ordering: true).except(:order).pluck(:id)
    end

    # Return the list of thing ids for nested queries.
    #
    # Nested queries ignore ordering and locale, as these are handled in the base query.
    def thing_ids_nested
      clear_thing_cache! if parameters_changed? && !new_record?
      @thing_ids_nested ||= things_nested.except(:order).pluck(:id)
    end

    # Return the list of things for the filter result.
    def things(**)
      clear_thing_cache! if parameters_changed? && !new_record?
      @things ||= apply(**).query
    end

    # Return a nested variant of `things` suitable for embedding in other queries.
    #
    # Nested queries ignore ordering and locale, as these are handled in the base query.
    def things_nested(**)
      clear_thing_cache! if parameters_changed? && !new_record?
      @things_nested ||= apply_nested(**).query
    end

    # Reload the record and clear cached query/ids to ensure up-to-date results.
    def reload(options = nil)
      clear_thing_cache!
      super
    end

    # Build and return the query for this stored filter.
    #
    # Parameters:
    # - `query`: a base query to apply filters to.
    # - `skip_ordering`: whether to avoid applying order parameters.
    # - `watch_list`: optional ordering context if applying order parameters.
    def apply(query: nil, skip_ordering: false, watch_list: nil)
      self.query = query || (cached_result? ? cached_query : default_query(include_embedded:))

      apply_filter_parameters!
      apply_order_parameters!(watch_list) unless skip_ordering

      self.query
    end

    # Build and return the nested query form of this stored filter;
    #
    # Nested queries ignore ordering and locale, as these are handled in the base query.
    def apply_nested
      self.query = cached_result? ? cached_query(locale: 'all') : default_query(locale: 'all', include_embedded:)
      apply_filter_parameters!

      query.reset_sort
    end

    # Compare two filter parameter hashes for type-equality.
    #
    # Only a subset of keys are considered relevant for determining whether two filters are of the same type;
    # context (`c`) may be ignored by the caller when `consider_context` is false.
    def filter_type_equal?(filter1, filter2, consider_context: true)
      keys = KEYS_FOR_TYPE_EQUALITY
      keys -= ['c'] unless consider_context
      filter1.slice(*keys) == filter2.slice(*keys)
    end

    # Compare two filter parameter hashes for full equality.
    #
    # Takes into account values and composite `union` filters.
    def filter_equal?(filter1, filter2, consider_context: true)
      keys = KEYS_FOR_TYPE_EQUALITY
      keys -= ['c'] unless consider_context
      keys += ['v']

      if filter1['t'] == 'union'
        keys -= ['v']
        return false unless filter1['v']&.size == filter2['v']&.size &&
                            filter1['v'].each_with_index.all? do |f1, index|
                              filter_equal?(f1, filter2['v'][index], consider_context: consider_context)
                            end
      end

      filter1.slice(*keys) == filter2.slice(*keys)
    end

    # Build a UI-friendly select option representation for this stored filter used in dropdowns.
    def to_select_option(locale = DataCycleCore.ui_locales.first)
      DataCycleCore::Filter::SelectOption.new(
        id:,
        name: ActionController::Base.helpers.safe_join([
          ActionController::Base.helpers.tag.i(class: 'fa dc-type-icon stored_filter-icon'),
          name.presence || '__DELETED__'
        ].compact, ' '),
        html_class: model_name.param_key,
        dc_tooltip: "#{model_name.human(count: 1, locale:)}: #{name.presence || '__DELETED__'}",
        class_key: model_name.param_key
      )
    end

    # Validate a content item by performing a duplicate search based on the provided primary key and content data.
    def self.validate_by_duplicate_search(content, datahash, primary_key, _current_user, active_ui_locale)
      return {} if datahash.blank? || primary_key.blank? || content.properties_for(primary_key)['type'] != 'string'

      value = datahash&.dig(primary_key)

      return {} if value.blank?

      data_type_definition = content.properties_for('data_type') || content.properties_for('schema_types')
      tree_label = data_type_definition&.dig('tree_label')
      internal_name = content.respond_to?(:data_type) ? data_type_definition&.dig('default_value') : content.schema_ancestors&.flatten&.last
      classification_alias_ids = DataCycleCore::ClassificationAlias.for_tree(tree_label).with_internal_name(internal_name).pluck(:id)

      filter = new(language: [I18n.locale.to_s], parameters: [
                     {
                       'c' => 'a',
                       'n' => I18n.t('common.searchterm', locale: active_ui_locale),
                       't' => 'fulltext_search',
                       'v' => value,
                       'identifier' => SecureRandom.hex(10)
                     },
                     {
                       'c' => 'a',
                       'm' => 'i',
                       'n' => tree_label,
                       't' => 'classification_alias_ids',
                       'v' => classification_alias_ids,
                       'identifier' => SecureRandom.hex(10)
                     }
                   ])

      filter.readonly!

      duplicate_count = filter.apply(skip_ordering: true).query.reorder(nil).size

      return {} if duplicate_count.zero?

      dup_confirm_diag = <<~DIAG.squish
        <p>#{I18n.t('duplicate_search.found_html', count: duplicate_count, locale: active_ui_locale)}!</p>
        <p>#{I18n.t('duplicate_search.continue_creation', locale: active_ui_locale)}</p>
      DIAG

      content.warnings.add(primary_key, I18n.t('duplicate_search.found_html', count: duplicate_count, locale: active_ui_locale))

      {
        duplicate_search: {
          count: duplicate_count,
          popup_text: dup_confirm_diag,
          filter_params: filter.parameters
        }
      }
    end

    # Create a `StoredFilter` instance from a property definition hash used in schema/property descriptors.
    #
    # Supports both `stored_filter` (explicit parameters) and `template_name` shorthand.
    def self.from_property_definition(definition)
      raise ArgumentError, 'definition must be a Hash' unless definition.is_a?(::Hash)

      if definition.key?('stored_filter')
        new(parameters: definition['stored_filter'])
      elsif definition.key?('template_name')
        new(parameters: [{
          't' => 'template_names',
          'v' => definition['template_name']
        }])
      else
        raise ArgumentError, "Invalid definition: #{definition}"
      end
    end

    # Build a lightweight copy of this stored filter suitable for embedding in other objects.
    def to_stored_filter
      self.class.new(parameters:, sort_parameters:, linked_stored_filter_id:)
    end

    # API v4 type string used by external clients.
    def api_v4_type
      API_V4_TYPE
    end

    # Derive the database representation name used for SQL-resolved filters.
    #
    # Returns nil if the record has no id.
    def sql_representation_name
      return if id.blank?

      "stored_filter_#{id.to_s.tr('-', '_')}"
    end

    # The stored-filter ids referenced by the given `parameters` array via relation/filter_ids types.
    # `v` holds id string(s) for these types; non-string entries (e.g. nested hashes) are ignored.
    def self.referenced_stored_filter_ids(parameters)
      Array.wrap(parameters).flat_map { |filter|
        next [] unless filter.is_a?(::Hash) && filter['t'].in?(SELF_REFERENCE_FILTER_TYPES)

        Array.wrap(filter['v']).grep(String)
      }.uniq
    end

    # Whether this filter references itself, directly or transitively: following its relation/filter_ids
    # references (and theirs, and so on) leads back to this filter. Such a filter resolves to itself and
    # cannot be executed (infinite recursion).
    #
    # Returns false for an unsaved record (no id yet - the database assigns the uuid on insert), so a
    # fresh create cannot be flagged. This is harmless: a filter can only reference an id that already
    # exists, so the condition is reached by *updating* a filter to point at its own id (or into a
    # cycle), never by a plain create.
    #
    # Traversal is a breadth-first walk over the reference graph that issues only one query per level
    # (all referenced filters of the current frontier are loaded at once), and a visited set bounds it
    # so unrelated cycles cannot loop forever. The validation is additionally gated on
    # `parameters_changed?`, so unrelated saves (e.g. a name change) skip it entirely.
    def self_referential?
      return false if id.blank? || parameters.blank?

      visited = Set.new
      frontier = self.class.referenced_stored_filter_ids(parameters)

      until frontier.empty?
        return true if frontier.include?(id)

        visited.merge(frontier)
        # one query per level: load every referenced filter of the current frontier together.
        next_parameters = self.class.where(id: frontier).pluck(:parameters)
        frontier = next_parameters.flat_map { |params| self.class.referenced_stored_filter_ids(params) }
          .uniq - visited.to_a
      end

      false
    end

    # Drop the persisted SQL representation for this stored filter, if it exists.
    def drop_sql_representation!
      return if sql_representation_name.blank?

      self.class.connection.execute("DROP FUNCTION IF EXISTS public.#{sql_representation_name}()")
    end

    # Create or replace the SQL representation of this stored filter.
    #
    # A SQL representation is only created for named stored filters.
    # If a stored filter is "deleted" by removing its name, the SQL representation is therefore dropped as well.
    def sync_sql_representation!
      return if sql_representation_name.blank?
      return drop_sql_representation! if name.blank?

      cached_before = cached_result
      # `except(:order)` strips the default ORDER BY: the representation is consumed as a
      # membership set, so any ordering is pure overhead (a wasted sort on every resolve).
      filter_sql = cached(false).apply(skip_ordering: true).except(:order).select(:id).to_sql
      self.cached_result = cached_before

      # Use a randomized dollar-quote tag guaranteed not to occur in the body, so a filter
      # value containing a literal "$func$" cannot break out of the function definition (SQL injection).
      quote_tag = "dc_sql_repr_#{SecureRandom.hex(16)}"
      quote_tag = "dc_sql_repr_#{SecureRandom.hex(16)}" while filter_sql.include?("$#{quote_tag}$")

      self.class.connection.execute(<<~SQL.squish)
        CREATE OR REPLACE FUNCTION public.#{sql_representation_name}()
        RETURNS SETOF uuid
        LANGUAGE sql
        STABLE
        SET search_path = public
        AS $#{quote_tag}$
          #{filter_sql}
        $#{quote_tag}$;
      SQL
    end

    private

    def must_not_reference_itself
      errors.add(:parameters, :self_referential) if self_referential?
    end

    def sql_representation_update_needed?
      saved_change_to_id? ||
        saved_change_to_name? ||
        saved_change_to_parameters? ||
        (respond_to?(:saved_change_to_sort_parameters?) && saved_change_to_sort_parameters?)
    end

    def clear_thing_cache!
      remove_instance_variable(:@thing_ids) if instance_variable_defined?(:@thing_ids)
      remove_instance_variable(:@thing_ids_nested) if instance_variable_defined?(:@thing_ids_nested)
      remove_instance_variable(:@things) if instance_variable_defined?(:@things)
      remove_instance_variable(:@things_nested) if instance_variable_defined?(:@things_nested)
    end

    def locale
      return if language.blank?
      return if language&.include?('all')

      language
    end

    def default_query(include_embedded: false, locale: language)
      locale = Array.wrap(locale).presence
      locale = nil if locale&.include?('all')

      DataCycleCore::Filter::Search.new(
        locale:,
        include_embedded: include_embedded || false,
        cached_result:
      )
    end
  end
end
