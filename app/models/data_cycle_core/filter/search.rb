# frozen_string_literal: true

module DataCycleCore
  module Filter
    class Search < QueryBuilder
      include DataCycleCore::Filter::Common::Advanced
      include DataCycleCore::Filter::Common::Classification
      include DataCycleCore::Filter::Common::Date
      include DataCycleCore::Filter::Common::External
      include DataCycleCore::Filter::Common::Fulltext
      include DataCycleCore::Filter::Common::Geo
      include DataCycleCore::Filter::Sortable

      def initialize(locale = ['de'], query = nil, include_embedded = false)
        @locale = locale
        @include_embedded = include_embedded

        @query = query || default_query
      end

      def default_query
        query = DataCycleCore::Thing.where(template: false)
        query = query.where.not(content_type: 'embedded') unless @include_embedded
        query = query.order('things.boost DESC, things.updated_at DESC, things.id ASC')
        query
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

      def with_content_ids(ids = nil)
        return self if ids.blank?

        reflect(
          @query.where(thing[:id].in(ids))
        )
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

      # Deprecated: replace with modified_at
      def modified_since(_date = Time.zone.now)
        raise DataCycleCore::Error::DeprecatedMethodError, "Deprecated method not implemented: #{__method__}"
      end

      # Deprecated: replace with created_at
      def created_since(_date = Time.zone.now)
        raise DataCycleCore::Error::DeprecatedMethodError, "Deprecated method not implemented: #{__method__}"
      end

      # Deprecated: no replacement
      def exclude_templates_embedded
        raise DataCycleCore::Error::DeprecatedMethodError, "Deprecated method not implemented: #{__method__}"
      end

      # Deprecated: replace with sort_fulltext_search or sort_by_proximity
      def self.get_order_by_query_string(_search, _events = false)
        raise DataCycleCore::Error::DeprecatedMethodError, "Deprecated method not implemented: #{__method__}"
      end

      # Deprecated: no replacement
      def distinct_by_content_id(_order_string = nil)
        raise DataCycleCore::Error::DeprecatedMethodError, "Deprecated method not implemented: #{__method__}"
      end

      # Deprecated: replace with count
      def count_distinct
        raise DataCycleCore::Error::DeprecatedMethodError, "Deprecated method not implemented: #{__method__}"
      end
    end
  end
end
