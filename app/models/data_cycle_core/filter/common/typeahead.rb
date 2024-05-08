# frozen_string_literal: true

module DataCycleCore
  module Filter
    module Common
      module Typeahead
        def typeahead(typeahead_text, language = ['de'], limit = 10)
          return [] if typeahead_text.blank?
          normalized_search = typeahead_text.unicode_normalize(:nfkc)
          locale = language.first # typeahead only supports one language!
          typeahead_query = <<-SQL
            SELECT word, word <-> ? as score
            FROM ts_stat($$
              #{
                @query
                  .except(:order)
                  .joins(:searches)
                  .where('searches.locale = ?', locale)
                  .select('searches.words_typeahead')
                  .to_sql
              }
            $$)
            ORDER BY score
            LIMIT ?
          SQL
          ActiveRecord::Base.connection.execute(
            ActiveRecord::Base.send(:sanitize_sql_array, [typeahead_query, normalized_search, limit])
          )
        end
      end
    end
  end
end
