# frozen_string_literal: true

module DataCycleCore
  module Filter
    class Search < QueryBuilder
      include DataCycleCore::Filter::Common::Advanced
      include DataCycleCore::Filter::Common::Classification
      include DataCycleCore::Filter::Common::Date
      include DataCycleCore::Filter::Common::External
      include DataCycleCore::Filter::Common::Geo
      include DataCycleCore::Filter::Sort

      # TODO: refactor initializer
      def initialize(locale = ['de'], query = nil, joined_search = false, joined_schedule = false)
        @locale = locale
        @joined_search = joined_search
        @joined_schedule = joined_schedule

        @query = query || DataCycleCore::Thing
          .where(template: false).where.not(content_type: 'embedded')

        # @query = query || DataCycleCore::Thing
        #   .joins(:searches)
        #   .where(searches: { locale: @locale })

        # if locale.nil?
        #   @query = query || DataCycleCore::Thing
        # else
        #   @query = query || DataCycleCore::Thing
        #   .joins(:searches)
        #   .where(searches: { locale: @locale })
        # temporary disabled disabled (api sort name)
        # .joins('LEFT JOIN thing_translations ON thing_translations.thing_id = things.id AND thing_translations.locale = searches.locale')
        # end
      end

      def content_includes
        reflect(
          @query.includes(
            :translations,
            :watch_lists,
            :external_source,
            :external_systems,
            :parent,
            :primary_classification_aliases,
            classification_aliases: [:classification_alias_path, :classification_tree_label]
          )
        )
      end

      def exclude_templates_embedded
        reflect(
          @query.where(template: false).where.not(content_type: 'embedded')
        )
      end

      def subscribed_user_id(id = nil)
        return self if id.blank?

        reflect(
          @query.where(subscription.where(subscription[:subscribable_id].eq(thing[:id]).and(subscription[:user_id].eq(id))).exists)
        )
      end

      def creator(ids = nil)
        return self if ids.blank?

        reflect(
          @query.where(thing[:created_by].in(ids))
        )
      end

      def schema_type(type)
        return self if type.blank?
        query_string = Thing.send(:sanitize_sql_for_conditions, ['(schema -> :attribute_path)::jsonb ? :type', attribute_path: 'schema_type', type: type])
        reflect(
          @query.where(Arel.sql(query_string))
        )
      end

      def watch_list_id(id = nil)
        return self if id.blank?

        reflect(
          @query.where(watch_list_data_hash.where(watch_list_data_hash[:hashable_id].eq(thing[:id]).and(watch_list_data_hash[:watch_list_id].eq(id))).exists)
        )
      end

      def part_of(id = nil)
        return self if id.blank?

        reflect(
          @query.where(thing[:is_part_of].eq(id))
        )
      end

      def relation(name = nil)
        return self if name.blank?

        reflect(
          @query.where(content_content.where(content_content[:content_a_id].eq(thing[:id]).and(content_content[:relation_a].eq(name))).exists)
        )
      end

      def relation_filter(filter = nil, name = nil)
        return self if name.blank?
        return self if filter.blank?

        if filter.is_a?(DataCycleCore::Filter::Search)
          filter_query = filter.select(:id).except(:order).to_sql
        else
          stored_filter = DataCycleCore::StoredFilter.find(filter)
          return self if stored_filter.blank?
          filter_query = stored_filter.apply.select(:id).except(:order).to_sql
        end

        thing_id = :content_a_id
        relation = :relation_a
        filtered_id = :content_b_id

        subquery = Arel::SelectManager.new
                     .from(content_content)
                     .where(
                       content_content[thing_id].eq(thing[:id])
                         .and(content_content[relation].eq(name))
                         .and(content_content[filtered_id].in(Arel.sql(filter_query)))
                     )

        reflect(
          @query.where(subquery.exists)
        )
      end

      def related_to(filter_id = nil)
        return self if filter_id.blank?
        filter = DataCycleCore::StoredFilter.find(filter_id)
        return self if filter.blank?

        thing_id = :content_b_id
        filtered_id = :content_a_id

        filter_query = filter.apply.select(:id).except(:order).to_sql
        subquery = Arel::SelectManager.new
                     .from(content_content)
                     .where(
                       content_content[thing_id].eq(thing[:id])
                         .and(content_content[filtered_id].in(Arel.sql(filter_query)))
                     )

        reflect(
          @query.where(subquery.exists)
        )
      end

      def modified_since(date = Time.zone.now)
        reflect(
          @query.where(search[:updated_at].gteq(Time.zone.parse(date)))
        )
      end

      def created_since(date = Time.zone.now)
        reflect(
          @query.where(search[:created_at].gteq(Time.zone.parse(date)))
        )
      end

      def with_content_ids(ids = nil)
        return self if ids.blank?

        reflect(
          @query.where(thing[:id].in(ids))
        )
      end

      # TODO: raise DeprecationError
      def distinct_by_content_id(order_string = nil)
        return self
      end

      def count_distinct
        return @query.except(:order, :limit, :offset).count unless (@joined_search && @locale.blank?) || @locale&.many? || @joined_schedule
        @query.except(:order, :limit, :offset).count('DISTINCT things.id')
      end

      def boolean(value, filter_method)
        if respond_to?(filter_method)
          send(filter_method, value)
        else
          self
        end
      end

      def duplicate_candidates(value)
        if value == 'true'
          reflect(
            @query.where(duplicate_candidate.where(duplicate_candidate[:duplicate_id].eq(thing[:id]).and(duplicate_candidate[:false_positive].eq(false))).exists)
          )
        else
          reflect(
            @query.where(duplicate_candidate.where(duplicate_candidate[:duplicate_id].eq(thing[:id]).and(duplicate_candidate[:false_positive].eq(false))).exists.not)
          )
        end
      end

      def fulltext_search(name)
        return self if name.blank?
        @joined_search = true
        normalized_name = name.unicode_normalize(:nfkc)

        reflect(
          @query
            .where(
              search_exists(
                search[:all_text].matches_all(normalized_name.split(' ').map { |item| "%#{item.strip}%" })
                  .or(tsmatch(search[:words], tsquery(quoted(normalized_name.squish))))
              )
            )
        )
      end

      def self.get_order_by_query_string(search, events = false)
        return ActiveRecord::Base.send(:sanitize_sql_for_order, Arel.sql('things.boost DESC, things.updated_at DESC')) if search.blank? && events == false
        return ActiveRecord::Base.send(:sanitize_sql_for_order, Arel.sql('things.end_date ASC NULLS LAST, things.start_date DESC NULLS LAST, things.updated_at DESC')) if events == true
        search_string = (search || '').split(' ').join('%')

        ActiveRecord::Base.send(
          :sanitize_sql_array,
          [
            Arel.sql(
              "things.boost * (
              8 * similarity(searches.classification_string, :search_string) +
              4 * similarity(searches.headline, :search_string) +
              2 * ts_rank_cd(searches.words, plainto_tsquery('simple', :search),16) +
              1 * similarity(searches.full_text, :search_string))
              DESC NULLS LAST,
              things.updated_at DESC"
            ),
            search_string: "%#{search_string}%",
            search: (search || '').squish
          ]
        )
      end

      def self.sort_params_from_filter(search, events = false)
        if search.blank? && events == false
          return [
            {
              "method": 'boost',
              "table": 'things',
              "value": 'DESC',
              "sorting": 0
            },
            {
              "method": 'updated_at',
              "table": 'things',
              "value": 'DESC',
              "sorting": 1
            }
          ]
        end
        if events == true
          return [
            {
              "method": 'end_date',
              "table": 'things',
              "value": 'ASC',
              "sorting": 0
            },
            {
              "method": 'start_date',
              "table": 'things',
              "value": 'DESC NULLS LAST',
              "sorting": 1
            },
            {
              "method": 'updated_at',
              "table": 'things',
              "value": 'DESC',
              "sorting": 2
            }
          ]
        end
        [
          {
            "method": 'fulltext_search',
            "table": 'searches',
            "value": 'DESC',
            "sorting": 0
          }
        ]
      end
    end
  end
end
