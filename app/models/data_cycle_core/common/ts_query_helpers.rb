# frozen_string_literal: true

module DataCycleCore
  module Common
    module TsQueryHelpers
      TS_QUERY_EXCEPTIONS = %r{[\&\|\<\>/\\\(\)\{\}\[\]\s:!]|(?<!\s)-}

      def text_to_tsquery(name, separator = '&', weights = '*')
        normalized_name = name.unicode_normalize(:nfkc)
        normalized_name.gsub(TS_QUERY_EXCEPTIONS, ' ').tr('-', '!').squish.split.map { |v| weights.present? ? "#{v}:#{weights.upcase}" : v }.join(" #{separator} ")
      end

      def text_to_websearch_tsquery(name)
        name.to_s.unicode_normalize(:nfkc).gsub(' - ', ' ')
      end
    end
  end
end
