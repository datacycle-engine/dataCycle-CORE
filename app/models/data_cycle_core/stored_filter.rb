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
  end
end
