# frozen_string_literal: true

module DataCycleCore
  class StoredFilter < ApplicationRecord
    scope :by_user, ->(user) { where user: user }
    belongs_to :user

    has_many :activities, as: :activitiable, dependent: :destroy

    belongs_to :linked_stored_filter, class_name: 'DataCycleCore::StoredFilter', inverse_of: :filter_uses, dependent: nil
    has_many :filter_uses, class_name: 'DataCycleCore::StoredFilter', foreign_key: :linked_stored_filter_id, inverse_of: :linked_stored_filter, dependent: :nullify

    # Mögliche Filter-Parameter: c, t, v, m, n, q
    #
    # c => 'd' oder 'a'         | für 'default' oder 'advanced'
    # t => String               | der Filtertyp (die Methode, die auf die Query ausgeführt wird, z.B. 'classification_alias_ids')
    # v => String oder Array    | der übergebene Wert für die Filtermethode (z.B. ['a9b25ff1-5af2-4f21-b61e-408812e14b0d'])             |
    # m => 'i', 'e', 'g', 'l', 'u', 'n', 's', 'b', 'p'    | Filtermethode, 'include', 'exclude', 'greater', 'lower', 'neutral', 'like', 'notLike', 'blank', 'present'
    # n => String               | das Filterlabel (z.B. 'Inhaltspools')
    # q => String (Optional)    | Ein spezifischer Query-Pfad für das Attribut (z.B. metadata ->> 'width') || type

    def apply(query: nil)
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

        # TODO: this is a quickfix, refactor it
        if filter['t'] == 'geo_filter'
          t = filter['q']
          t = "not_#{t}" if filter['m'] == 'e'
        end

        next unless query.respond_to?(t)

        if query.method(t)&.parameters&.size == 3
          query = query.send(t, filter['v'], filter['q'].presence, filter['n'].presence)
        elsif query.method(t)&.parameters&.size == 2
          query = query.send(t, filter['v'], filter['q'].presence || filter['n'].presence)
        else
          query = query.send(t, filter['v'])
        end
      end

      if sort_parameters.present?
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

    def self.sort_params_from_filter(search = nil, schedule = nil)
      if search.present?
        [
          {
            "m": 'fulltext_search',
            "o": 'DESC',
            "v": search
          }
        ]
      elsif schedule.present?
        [
          {
            "m": 'by_proximity',
            "o": 'ASC',
            "v": schedule
          }
        ]
      end
    end

    def self.combine_with_collections(collections, filter_proc)
      query1_table = all.arel_table
      query1 = all.arel
      query1.projections = []
      query1 = query1.where(query1_table[:name].not_eq(nil)).project(query1_table[:id], query1_table[:name], Arel::Nodes::SqlLiteral.new("'stored_filter'").as('class_name'))

      query2_table = collections.arel_table
      query2 = collections.arel
      query2.projections = []
      query2 = query2.where(query2_table[:name].not_eq(nil)).project(query2_table[:id], query2_table[:name], Arel::Nodes::SqlLiteral.new("'watch_list'").as('class_name'))

      unless filter_proc.nil?
        query1 = filter_proc.call(query1, query1_table)
        query2 = filter_proc.call(query2, query2_table)
      end

      query = Arel::SelectManager.new(Arel::Nodes::TableAlias.new(query1.union(:all, query2), 'combined_collections_and_searches')).project(Arel.star).order('name ASC')
      query
    end
  end
end
