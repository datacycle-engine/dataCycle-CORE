# frozen_string_literal: true

module DataCycleCore
  module Filter
    class Search < QueryBuilder
      include DataCycleCore::Filter::Common::Advanced
      include DataCycleCore::Filter::Common::Classification
      include DataCycleCore::Filter::Common::Date
      include DataCycleCore::Filter::Common::External
      include DataCycleCore::Filter::Common::Geo

      def initialize(locale = ['de'], query = nil, joined_search = false, joined_schedule = false)
        @locale = locale
        @joined_search = joined_search
        @joined_schedule = joined_schedule
        if locale.nil?
          @query = query || DataCycleCore::Thing
        else
          @query = query || DataCycleCore::Thing.joins(:searches).where(searches: { locale: @locale })
        end
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

      def relation_filter(filter_id = nil, name = nil)
        return self if name.blank?
        return self if filter_id.blank?
        filter = DataCycleCore::StoredFilter.find(filter_id)
        return self if filter.blank?

        if inverse
          thing_id = :content_b_id
          relation = :relation_b
          filtered_id = :content_a_id
        else
          thing_id = :content_a_id
          relation = :relation_a
          filtered_id = :content_b_id
        end

        filter_query = filter.apply(experimental: true).select(:id).except(:order).to_sql
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

      def distinct_by_content_id(order_string = nil)
        return self unless (@joined_search && @locale.blank?) || @locale&.many? || @joined_schedule

        reflect(
          if (@joined_search && @locale.blank?) || @locale&.many?
            DataCycleCore::Thing.joins(:searches)
              .where(searches: {
                id: @query.select('DISTINCT ON (things.id) searches.id').except(:limit, :offset).reorder(ActiveRecord::Base.send(:sanitize_sql_for_order, Arel.sql('things.id ASC' + (order_string.present? ? ', ' + order_string.to_s : ''))))
              })
              .order(order_string.present? ? Arel.sql(order_string) : order_string)
          elsif @joined_schedule
            DataCycleCore::Thing
              .where(things: {
                id: @query.select('DISTINCT ON (things.id) things.id').except(:limit, :offset).reorder(ActiveRecord::Base.send(:sanitize_sql_for_order, Arel.sql('things.id ASC' + (order_string.present? ? ', ' + order_string.to_s : ''))))
              })
              .order(order_string.present? ? Arel.sql(order_string) : order_string)
          end
        )
      end

      def count_distinct
        return @query.except(:order, :limit, :offset).count unless (@joined_search && @locale.blank?) || @locale&.many? || @joined_schedule
        # @query.except(:order, :limit, :offset).count('DISTINCT id') if @joined_schedule
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
            .joins(:searches)
            .where(
              search[:all_text].matches_all(normalized_name.split(' ').map { |item| "%#{item.strip}%" })
                .or(tsmatch(search[:words], tsquery(quoted(normalized_name.squish))))
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
    end
  end
end
