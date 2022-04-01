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
            SELECT word, word <-> \'#{normalized_search}\' score
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
            LIMIT #{limit}
          SQL
          ActiveRecord::Base.connection.execute(
            ActiveRecord::Base.send(:sanitize_sql, typeahead_query)
          )
        end
      end
    end
  end
end
