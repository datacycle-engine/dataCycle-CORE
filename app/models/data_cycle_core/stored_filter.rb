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
    # m => 'i', 'e', 'g', 'l' oder 'n'    | Filtermethode, 'include', 'exclude', 'greater', 'lower' oder 'neutral'
    # n => String               | das Filterlabel (z.B. 'Inhaltspools')
    # q => String (Optional)    | Ein spezifischer Query-Pfad für das Attribut (z.B. metadata ->> 'width') || type

    def apply(query: nil)
      query_params = language.include?('all') ? [nil] : [language]
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
        else
          t = filter['t']
        end

        # TODO: migrate stored filters to use latest classification filter methods
        t = "#{t}_with_subtree" if (filter['t'] == 'classification_alias_ids' || filter['t'] == 'not_classification_alias_ids') && !language.include?('all')

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
  end
end
