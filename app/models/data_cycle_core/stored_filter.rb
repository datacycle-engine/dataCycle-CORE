# frozen_string_literal: true

module DataCycleCore
  class StoredFilter < ApplicationRecord
    # Mögliche Filter-Parameter: c, t, v, m, n, q
    #
    # c => one of 'd', 'a', 'p', 'u', 'uf'                | für 'default', 'advanced', 'permanent advanced', 'user', 'user forced'
    # t => String                                         | der Filtertyp (die Methode, die auf die Query ausgeführt wird, z.B. 'classification_alias_ids')
    # v => String, Array, Hash                            | der übergebene Wert für die Filtermethode (z.B. ['a9b25ff1-5af2-4f21-b61e-408812e14b0d'])
    # m => 'i', 'e', 'g', 'l', 'u', 'n', 's', 'b', 'p'    | Filtermethode, 'include', 'exclude', 'greater', 'lower', 'neutral', 'like', 'notLike', 'blank', 'present'
    # n => String                                         | das Filterlabel (z.B. 'Inhaltspools')
    # q => String (Optional)                              | Ein spezifischer Query-Pfad für das Attribut (z.B. metadata ->> 'width') || type

    scope :by_user, ->(user) { where user: user }
    belongs_to :user

    has_many :activities, as: :activitiable, dependent: :destroy

    belongs_to :linked_stored_filter, class_name: 'DataCycleCore::StoredFilter', inverse_of: :filter_uses, dependent: nil
    has_many :filter_uses, class_name: 'DataCycleCore::StoredFilter', foreign_key: :linked_stored_filter_id, inverse_of: :linked_stored_filter, dependent: :nullify

    has_many :data_links, as: :item, dependent: :destroy
    has_many :valid_write_links, -> { valid.writable }, class_name: 'DataCycleCore::DataLink', as: :item

    KEYS_FOR_EQUALITY = ['t', 'c', 'n'].freeze
    FILTER_PREFIX = {
      'e' => 'not_',
      'g' => 'greater_',
      'l' => 'lower_',
      's' => 'like_',
      'u' => 'not_like_',
      'b' => 'not_exists_',
      'p' => 'exists_'
    }.freeze

    def apply(query: nil, skip_ordering: false)
      query_params = language&.exclude?('all') ? [language] : [nil]
      query ||= DataCycleCore::Filter::Search.new(*query_params)

      parameters.presence&.each do |filter|
        t = filter['t'].dup
        t.prepend(FILTER_PREFIX[filter['m']].to_s)

        t.concat('_with_subtree') if filter['t'].in?(['classification_alias_ids', 'not_classification_alias_ids'])
        next unless query.respond_to?(t)

        if query.method(t)&.parameters&.size == 3
          query = query.send(t, filter['v'], filter['q'].presence, filter['n'].presence)
        elsif query.method(t)&.parameters&.size == 2
          query = query.send(t, filter['v'], filter['q'].presence || filter['n'].presence)
        else
          query = query.send(t, filter['v'])
        end
      end

      if sort_parameters.present? && !skip_ordering
        query = query.reset_sort
        sort_parameters.each do |sort|
          sort_method_name = 'sort_' + sort['m']

          if sort['m'].starts_with?('advanced_attribute_')
            sort['v'] = sort['m'].gsub('advanced_attribute_', '')
            sort_method_name = 'sort_advanced_attribute'
          end

          next unless query.respond_to?(sort_method_name)

          if query.method(sort_method_name)&.parameters&.size == 2
            query = query.send(sort_method_name, sort['o'].presence, sort['v'].presence)
          elsif query.method(sort_method_name)&.parameters&.size == 1
            query = query.send(sort_method_name, sort['o'].presence)
          else
            next
          end
        end
      end

      query
    end

    def parameters_from_hash(params_array)
      return self if params_array.blank?

      self.parameters = params_array.map { |filter| param_from_definition(filter) }

      self
    end

    def user_filters_from_hash(user, filter_options)
      user_filters = []

      Array.wrap(DataCycleCore.user_filters).each do |f|
        next if Array.wrap(f['scope']).exclude?(filter_options[:scope])
        next if Array.wrap(f['segments']).none? { |s| s['name'].safe_constantize.new(*Array.wrap(s['parameters'])).include?(user) }
        next if filter_options[:scope] == 'object_browser' && f['object_browser_restriction'].to_h.none? { |k, v| filter_options[:content_template] == k && filter_options[:attribute_key]&.in?(Array.wrap(v)) }

        user_filters.concat(Array.wrap(f['stored_filter']).map { |s| param_from_definition(s, f['force'] ? 'uf' : 'u', user) })
      end

      user_filters
    end

    def filter_equal?(filter1, filter2)
      filter1.slice(*KEYS_FOR_EQUALITY) == filter2.slice(*KEYS_FOR_EQUALITY)
    end

    def apply_user_filter(user, options = nil)
      return self if user.nil?

      filter_options = { scope: 'backend' }
      filter_options.merge!(options) { |_k, v1, v2| v2.presence || v1 } if options.present?

      self.parameters ||= []
      applicable_filters = user_filters_from_hash(user, filter_options)
      parameters.each { |f| f['c'] = 'a' if f['c'].in?(['u', 'uf']) && applicable_filters.none? { |af| filter_equal?(af, f) } }

      self.parameters = user.default_filter(parameters, filter_options) # keep for backwards compatibility

      applicable_filters.each { |f| apply_specific_user_filter(f) }

      self
    end

    def apply_specific_user_filter(filter)
      parameters.reject! { |f| filter_equal?(f, filter) } if filter['c'] == 'uf'
      parameters.push(filter) unless parameters.any? { |f| filter_equal?(f, filter) }
    end

    def self.sort_params_from_filter(search = nil, schedule = nil)
      if search.present?
        [
          {
            'm': 'fulltext_search',
            'o': 'DESC',
            'v': search
          }
        ]
      elsif schedule.present?
        [
          {
            'm': 'by_proximity',
            'o': 'ASC',
            'v': schedule
          }
        ]
      end
    end

    def self.combine_with_collections(collections, filter_proc, name_filter = true)
      query1_table = all.arel_table
      query1 = all.arel
      query1.projections = []
      query1 = query1.where(query1_table[:name].not_eq(nil)) if name_filter
      query1 = query1.project(query1_table[:id], query1_table[:name], Arel::Nodes::SqlLiteral.new("'#{all.klass.model_name.param_key}'").as('class_name'))

      query2_table = collections.arel_table
      query2 = collections.arel
      query2.projections = []
      query2 = query2.where(query2_table[:name].not_eq(nil)).project(query2_table[:id], query2_table[:name], Arel::Nodes::SqlLiteral.new("'#{collections.klass.model_name.param_key}'").as('class_name'))

      unless filter_proc.nil?
        query1 = filter_proc.call(query1, query1_table)
        query2 = filter_proc.call(query2, query2_table)
      end

      Arel::SelectManager.new(Arel::Nodes::TableAlias.new(query1.union(:all, query2), 'combined_collections_and_searches')).project(Arel.star).order('name ASC')
    end

    def to_select_option
      DataCycleCore::Filter::SelectOption.new(
        id,
        name.presence || '__DELETED__',
        model_name.param_key,
        name.presence || '__DELETED__'
      )
    end

    def valid_write_links?
      valid_write_links.present?
    end

    def apply_params_for_data_links(data_link_ids)
      stored_filter_ids = DataCycleCore::DataLink.where(id: data_link_ids, permissions: 'read').valid_stored_filters.ids

      return if stored_filter_ids.blank?

      apply_specific_user_filter(param_from_definition({ union_filter_ids: stored_filter_ids }, 'uf'))
    end

    private

    def param_from_definition(definition, type = 'a', user = nil)
      definition.to_h.deep_stringify_keys.each_with_object({}) do |(k, v), hash|
        hash['t'], hash['m'] = filter_method_from_prefix(k)
        hash['v'] = v
        hash['c'] = type
        hash['n'] = hash['t'].capitalize

        custom_param_transformation(hash, user)
      end
    end

    def custom_param_transformation(hash, user)
      case hash['t']
      when 'with_classification_aliases_and_treename'
        raise StandardError, 'Missing data definition: treeLabel' if hash.dig('v', 'treeLabel').blank?
        raise StandardError, 'Missing data definition: aliases' if hash.dig('v', 'aliases').blank?

        hash['t'] = 'classification_alias_ids'
        hash['n'] = hash.dig('v', 'treeLabel')
        hash['v'] = DataCycleCore::ClassificationAlias
          .for_tree(hash.dig('v', 'treeLabel'))
          .with_internal_name(hash.dig('v', 'aliases')).pluck(:id)
      when 'external_source'
        hash['t'] = 'external_system'
        hash['n'] = hash['t'].capitalize
        hash['q'] = 'import'
      when 'creator'
        hash['t'] = 'user'
        hash['n'] = 'creator'
        hash['q'] = 'creator'
        hash['v'] = Array.wrap(hash['v']).map { |v| v == 'current_user' ? user&.id : v }
      when 'with_user_group_classifications_for_treename'
        raise StandardError, 'Missing data definition: treeLabel' if hash['v'].blank?
        relation = DataCycleCore::Feature::UserGroupClassification.attribute_relations.find { |_k, v| v['tree_label'] == hash['v'] }&.first
        raise StandardError, "relation not found for UserGroup and treelabel (#{hash['v']})" if relation.blank?

        hash['t'] = 'classification_alias_ids'
        hash['n'] = hash['v']
        hash['v'] = user&.user_groups&.send(relation)&.pluck(:id)
      end
    end

    def filter_method_from_prefix(filter_type)
      f_method, f_prefix = FILTER_PREFIX.to_a.reverse.find { |_, prefix| filter_type.starts_with?(prefix) }

      return filter_type.delete_prefix(f_prefix.to_s), f_method || 'i'
    end
  end
end
