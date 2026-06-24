# frozen_string_literal: true

module DataCycleCore
  module Filter
    module Common
      module Fulltext
        extend ActiveSupport::Concern

        FULLTEXT_FIELDS = ['name', 'dc:slug', 'dc:classification'].freeze
        FULLTEXT_WEIGHTS = ['A', 'B', 'C'].freeze
        FULLTEXT_WEIGHT_MAP = FULLTEXT_FIELDS.zip(FULLTEXT_WEIGHTS).to_h.freeze

        def legacy_fulltext_search(value)
          value = value[:value] if value.is_a?(Hash)
          return self if value.blank?

          normalized_name = value.unicode_normalize(:nfkc)
          subquery = DataCycleCore::Search.select(1)
          subquery = subquery.where(locale: @locale) if @locale.present?
          subquery = subquery.left_outer_joins(:pg_dict_mapping)
          subquery = subquery.where(search[:content_data_id].eq(thing[:id]))
          all_matches = normalized_name.split.map { |item| "%#{item.strip}%" }
          subquery = subquery.where(search[:all_text].matches_all(all_matches))
            .or(subquery.where(tsmatch(search[:words], tsquery(quoted(normalized_name.squish), pg_dict_mapping[:dict]))))

          reflect(@query.where(subquery.arel.exists))
        end

        def ts_query_fulltext_search(value)
          value, fields = value.values_at(:value, :fields) if value.is_a?(Hash)
          return self if value.blank?

          q = text_to_websearch_tsquery(value)
          weights = fulltext_fields_to_weights(fields)
          subquery = DataCycleCore::Search.select(1)
          subquery = subquery.where(locale: @locale) if @locale.present?
          subquery = subquery.left_outer_joins(:pg_dict_mapping)
          subquery = subquery.where(search[:content_data_id].eq(thing[:id]))
          subquery = subquery.where(
            tsmatch(
              search[:search_vector],
              websearch_to_prefix_tsquery(q, pg_dict_mapping[:dict], weights)
            )
          )

          reflect(@query.where(subquery.arel.exists))
        end

        class_methods do
          def fulltext_fields_to_weights(fields_string)
            return '' if fields_string.blank?

            fields_string.split(',').map(&:strip).map { |f| FULLTEXT_WEIGHT_MAP[f] }.join.to_s.upcase
          end
        end

        delegate :fulltext_fields_to_weights, to: :class

        # used to alias the fulltext search method based on feature flag without class reloading
        def self.alias_fulltext_search_method!
          if Feature::TsQueryFulltextSearch.enabled?
            alias_method :fulltext_search, :ts_query_fulltext_search
          else
            alias_method :fulltext_search, :legacy_fulltext_search
          end
        end

        alias_fulltext_search_method!
      end
    end
  end
end
