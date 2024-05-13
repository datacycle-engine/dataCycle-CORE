# frozen_string_literal: true

module DataCycleCore
  class StoredFilter < Collection
    # Mögliche Filter-Parameter: c, t, v, m, n, q
    #
    # c => one of 'd', 'a', 'p', 'u', 'uf'                | für 'default', 'advanced', 'permanent advanced', 'user', 'user forced'
    # t => String                                         | der Filtertyp (die Methode, die auf die Query ausgeführt wird, z.B. 'classification_alias_ids')
    # v => String, Array, Hash                            | der übergebene Wert für die Filtermethode (z.B. ['a9b25ff1-5af2-4f21-b61e-408812e14b0d'])
    # m => 'i', 'e', 'g', 'l', 'u', 'n', 's', 'b', 'p'    | Filtermethode, 'include', 'exclude', 'greater', 'lower', 'neutral', 'like', 'notLike', 'blank', 'present'
    # n => String                                         | das Filterlabel (z.B. 'Inhaltspools')
    # q => String (Optional)                              | Ein spezifischer Query-Pfad für das Attribut (z.B. metadata ->> 'width') || type

    include StoredFilterExtensions::SortParamTransformations
    include StoredFilterExtensions::FilterParamsTransformations
    include StoredFilterExtensions::FilterParamsHashParser

    attr_accessor :query, :include_embedded

    KEYS_FOR_EQUALITY = ['t', 'c', 'n'].freeze

    def things(query: nil, skip_ordering: false, watch_list: nil)
      apply(query:, skip_ordering:, watch_list:).query
    end

    def apply(query: nil, skip_ordering: false, watch_list: nil)
      self.query = query || DataCycleCore::Filter::Search.new(language&.exclude?('all') ? language : nil, nil, include_embedded || false)

      apply_filter_parameters
      apply_order_parameters(watch_list) unless skip_ordering

      self.query
    end

    def filter_equal?(filter1, filter2)
      filter1.slice(*KEYS_FOR_EQUALITY) == filter2.slice(*KEYS_FOR_EQUALITY)
    end

    def to_select_option(locale = DataCycleCore.ui_locales.first)
      DataCycleCore::Filter::SelectOption.new(
        id,
        ActionController::Base.helpers.safe_join([
          ActionController::Base.helpers.tag.i(class: 'fa dc-type-icon stored_filter-icon'),
          name.presence || '__DELETED__'
        ].compact, ' '),
        model_name.param_key,
        "#{model_name.human(count: 1, locale:)}: #{name.presence || '__DELETED__'}"
      )
    end

    def self.validate_by_duplicate_search(content, datahash, primary_key, current_user, active_ui_locale)
      return {} if datahash.blank? || primary_key.blank?

      value = datahash&.dig(primary_key)

      return {} if value.blank?

      data_type_definition = content.properties_for('data_type') || content.properties_for('schema_types')
      tree_label = data_type_definition&.dig('tree_label')
      internal_name = content.respond_to?(:data_type) ? data_type_definition&.dig('default_value') : content.schema_ancestors&.flatten&.last
      classification_alias_ids = DataCycleCore::ClassificationAlias.for_tree(tree_label).with_internal_name(internal_name).pluck(:id)
      last_filter = current_user.stored_filters.order(created_at: :desc).first

      if last_filter&.parameters&.size&.==(2) && last_filter&.parameters&.any? { |f| f['t'] == 'fulltext_search' && f['v'] == value } && last_filter&.parameters&.any? { |f| f['t'] == 'classification_alias_ids' && f['v'] == classification_alias_ids }
        filter = last_filter
      else
        filter = create(user: current_user, language: [I18n.locale.to_s], parameters: [
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
      end

      duplicate_count = filter.apply(skip_ordering: true).query.reorder(nil).size

      return {} if duplicate_count.zero?

      dup_confirm_diag = <<-DIAG.squish
        <p>#{I18n.t('duplicate_search.found_html', count: duplicate_count, locale: active_ui_locale)}!</p>
        <p>#{I18n.t('duplicate_search.continue_creation', locale: active_ui_locale)}</p>
      DIAG

      content.warnings.add(primary_key, I18n.t('duplicate_search.found_html', count: duplicate_count, locale: active_ui_locale))

      {
        duplicate_search: {
          count: duplicate_count,
          popup_text: dup_confirm_diag,
          filter_id: filter.id
        }
      }
    end
  end
end
