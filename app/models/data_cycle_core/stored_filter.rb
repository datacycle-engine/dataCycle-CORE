# frozen_string_literal: true

module DataCycleCore
  class StoredFilter < ApplicationRecord
    scope :by_user, ->(user) { where user: user }
    belongs_to :user

    has_many :activities, as: :activitiable, dependent: :destroy

    belongs_to :linked_stored_filter, class_name: 'DataCycleCore::StoredFilter', inverse_of: :filter_uses, dependent: nil
    has_many :filter_uses, class_name: 'DataCycleCore::StoredFilter', foreign_key: :linked_stored_filter_id, inverse_of: :linked_stored_filter, dependent: :nullify

    has_many :data_links, as: :item, dependent: :destroy
    has_many :valid_write_links, -> { valid.writable }, class_name: 'DataCycleCore::DataLink', as: :item

    # Mögliche Filter-Parameter: c, t, v, m, n, q
    #
    # c => 'd' oder 'a'         | für 'default' oder 'advanced'
    # t => String               | der Filtertyp (die Methode, die auf die Query ausgeführt wird, z.B. 'classification_alias_ids')
    # v => String, Array, Hash  | der übergebene Wert für die Filtermethode (z.B. ['a9b25ff1-5af2-4f21-b61e-408812e14b0d'])             |
    # m => 'i', 'e', 'g', 'l', 'u', 'n', 's', 'b', 'p'    | Filtermethode, 'include', 'exclude', 'greater', 'lower', 'neutral', 'like', 'notLike', 'blank', 'present'
    # n => String               | das Filterlabel (z.B. 'Inhaltspools')
    # q => String (Optional)    | Ein spezifischer Query-Pfad für das Attribut (z.B. metadata ->> 'width') || type

    def apply(query: nil, skip_ordering: false)
      query_params = language&.exclude?('all') ? [language] : [nil]
      query ||= DataCycleCore::Filter::Search.new(*query_params)

      parameters.presence&.each do |filter|
        case filter['m']
        when 'e'
          t = "not_#{filter['t']}"
        when 'g'
          t = "greater_#{filter['t']}"
        when 'l'
          t = "lower_#{filter['t']}"
        when 's'
          t = "like_#{filter['t']}"
        when 'u'
          t = "not_like_#{filter['t']}"
        when 'b'
          t = "not_exists_#{filter['t']}"
        when 'p'
          t = "exists_#{filter['t']}"
        else
          t = filter['t']
        end

        # TODO: migrate stored filters to use latest classification filter methods
        t = "#{t}_with_subtree" if filter['t'] == 'classification_alias_ids' || filter['t'] == 'not_classification_alias_ids'

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
          next unless query.respond_to?('sort_' + sort['m'])

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

    def parameters_from_hash(params)
      return self if params.blank?

      self.parameters = params.map do |f|
        f.to_h.deep_stringify_keys.each_with_object({}) do |(k, v), hash|
          hash['t'] = k
          hash['v'] = v
        end
      end

      self
    end

    def apply_user_filter(user, options = nil)
      return self if user.nil?

      filter_options = { scope: 'backend' }
      filter_options.merge!(options) { |_k, v1, v2| v2.presence || v1 } if options.present?

      self.parameters = user.default_filter(parameters || [], filter_options)

      self
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

    def self.combine_with_collections(collections, filter_proc)
      query1_table = all.arel_table
      query1 = all.arel
      query1.projections = []
      query1 = query1.where(query1_table[:name].not_eq(nil)).project(query1_table[:id], query1_table[:name], Arel::Nodes::SqlLiteral.new("'#{all.klass.model_name.param_key}'").as('class_name'))

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
        name,
        model_name.param_key,
        name
      )
    end

    def valid_write_links?
      valid_write_links.present?
    end

    def apply_params_for_data_links(data_link_ids)
      stored_filter_ids = DataCycleCore::DataLink.where(id: data_link_ids, permissions: 'read').valid_stored_filters.ids

      return if stored_filter_ids.blank?

      if (union_filters = parameters&.filter { |f| f['t'] == 'union_filter_ids' && f['v'].intersection(stored_filter_ids).present? }).present?
        union_filters.each { |f| f['v'] = f['v'].intersection(stored_filter_ids) }
      else
        parameters << {
          'c' => 'a',
          't' => 'union_filter_ids',
          'n' => 'Union_filter_ids',
          'm' => 'i',
          'v' => stored_filter_ids
        }
      end
    end
  end
end
