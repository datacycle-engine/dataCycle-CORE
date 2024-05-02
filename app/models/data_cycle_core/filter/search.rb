# frozen_string_literal: true

module DataCycleCore
  module Filter
    class Search < QueryBuilder
      include DataCycleCore::Filter::Common::Advanced
      include DataCycleCore::Filter::Common::Classification
      include DataCycleCore::Filter::Common::Date
      include DataCycleCore::Filter::Common::External
      include DataCycleCore::Filter::Common::Id
      include DataCycleCore::Filter::Common::Fulltext
      include DataCycleCore::Filter::Common::Typeahead
      include DataCycleCore::Filter::Common::Geo
      include DataCycleCore::Filter::Common::Union
      include DataCycleCore::Filter::Common::User
      include DataCycleCore::Filter::Common::Graph
      include DataCycleCore::Filter::Sortable

      def initialize(locale = ['de'], query = nil, include_embedded = false)
        @locale = locale
        @include_embedded = include_embedded

        @query = query || default_query
      end

      def content_includes
        reflect(
          @query.includes(
            :translations,
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

      def updated_since_flat(updated_at = nil)
        return self if updated_at.blank?

        reflect(
          @query.where(thing[:updated_at].gteq(quoted(updated_at)))
        )
      end

      def updated_since(updated_at = nil, iteration_depth = 5)
        return self if updated_at.blank?

        updated_since = updated_at

        raw_sql = <<-SQL.squish
          WITH RECURSIVE content_dependencies AS (
            SELECT ARRAY[things.id] "content_ids"
              FROM things AS t
              WHERE t.id = things.id
              AND t.updated_at >= ?
            UNION
            SELECT ARRAY[content_content_links.content_b_id, content_content_links.content_a_id] "content_ids"
              FROM content_content_links
              JOIN things AS t ON t.id = content_content_links.content_b_id
              WHERE content_content_links.content_a_id = things.id
              AND content_content_links.relation IS NOT NULL
              AND t.updated_at >= ?
            UNION
            SELECT content_content_links.content_b_id || content_dependencies.content_ids "content_ids"
              FROM content_content_links
              JOIN things AS t ON t.id = content_content_links.content_b_id
              JOIN content_dependencies ON content_dependencies.content_ids[1] = content_content_links.content_a_id
              AND content_content_links.content_b_id <> ALL(content_dependencies.content_ids)
              AND t.updated_at >= ?
            WHERE array_length(content_dependencies.content_ids, 1) < ?
              AND content_content_links.relation IS NOT NULL
          ) SELECT 1 FROM content_dependencies WHERE content_ids[array_length(content_ids, 1)] = things.id
        SQL

        reflect(
          @query.where("EXISTS (#{ActiveRecord::Base.send(:sanitize_sql_array, [raw_sql, updated_since, updated_since, updated_since, iteration_depth])})")
        )
      end

      def schema_type(type)
        return self if type.blank?

        sql = <<-SQL.squish
          (
            CASE WHEN thing_templates.computed_schema_types IS NOT NULL THEN thing_templates.computed_schema_types && ARRAY[:type]::VARCHAR[]
            ELSE (schema -> :attribute_path)::jsonb ? :type
            END
          )
        SQL

        query_string = Thing.send(:sanitize_sql_for_conditions, [sql, attribute_path: 'schema_type', type:])

        reflect(
          @query.left_outer_joins(:thing_template).where(Arel.sql(query_string))
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

      def like_relation_filter(filter = nil, name = nil)
        return self if name.blank? || filter.blank?

        subquery = related_to_query(filter, name)
        return self if subquery.nil?

        reflect(
          @query.where(subquery.exists)
        )
      end

      def not_like_relation_filter(filter = nil, name = nil)
        return self if name.blank? || filter.blank?

        subquery = related_to_query(filter, name)
        return self if subquery.nil?

        reflect(
          @query.where.not(subquery.exists)
        )
      end

      def related_through_attribute(value, relation_name)
        if value.to_s == 'true'
          exists_relation_filter(relation_name, true)
        else
          not_exists_relation_filter(relation_name, true)
        end
      end

      def exists_relation_filter(name = nil, inverse = false)
        return self if name.blank?
        subquery = related_to_any(name, inverse == true)
        return self if subquery.nil?

        reflect(
          @query.where(subquery.project(1).exists)
        )
      end

      def not_exists_relation_filter(name = nil, inverse = false)
        return self if name.blank?
        subquery = related_to_any(name, inverse == true)
        return self if subquery.nil?

        reflect(
          @query.where.not(subquery.project(1).exists)
        )
      end

      def relation_filter(filter = nil, name = nil)
        return self if name.blank? || filter.blank?

        subquery = related_to_query(filter, name)
        return self if subquery.nil?

        reflect(
          @query.where(subquery.exists)
        )
      end

      def not_relation_filter(filter = nil, name = nil)
        return self if name.blank? || filter.blank?

        subquery = related_to_query(filter, name)
        return self if subquery.nil?

        reflect(
          @query.where.not(subquery.exists)
        )
      end

      def relation_filter_inv(filter = nil, name = nil)
        return self if name.blank? || filter.blank?

        subquery = related_to_query(filter, name, true)
        return self if subquery.nil?

        reflect(
          @query.where(subquery.exists)
        )
      end

      def not_relation_filter_inv(filter = nil, name = nil)
        return self if name.blank? || filter.blank?

        subquery = related_to_query(filter, name, true)
        return self if subquery.nil?

        reflect(
          @query.where.not(subquery.exists)
        )
      end

      def related_to(filter_id = nil)
        return self if filter_id.blank?

        subquery = related_to_query(filter_id, nil, true)
        return self if subquery.nil?

        reflect(
          @query.where(subquery.exists)
        )
      end

      def not_related_to(filter_id = nil)
        return self if filter_id.blank?

        subquery = related_to_query(filter_id, nil, true)
        return self if subquery.nil?

        reflect(
          @query.where.not(subquery.exists)
        )
      end

      def boolean(value, filter_method)
        if respond_to?(filter_method)
          send(filter_method, value)
        else
          self
        end
      end

      def duplicate_candidates(value, score = nil)
        sub_query = duplicate_candidate[:duplicate_id].eq(thing[:id]).and(duplicate_candidate[:false_positive].eq(false))
        sub_query = sub_query.and(duplicate_candidate[:score].gteq(score.to_i)) if score.present?

        if value.to_s == 'true'
          reflect(
            @query.where(duplicate_candidate.where(sub_query).exists)
          )
        else
          reflect(
            @query.where(duplicate_candidate.where(sub_query).exists.not)
          )
        end
      end

      def with_geom(value)
        if value.to_s == 'true'
          with_geometry
        else
          not_with_geometry
        end
      end

      def with_external_source(value)
        if value.to_s == 'true'
          with_external_system
        else
          not_with_external_system
        end
      end

      def template_names(names)
        return self if names.blank?

        reflect(
          @query.where(thing[:template_name].in(Array.wrap(names)))
        )
      end

      def exclude_ids(ids)
        return self if ids.blank?

        reflect(
          @query.where.not(thing[:id].in(Array.wrap(ids)))
        )
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

      private

      def related_to_query(filter, name = nil, inverse = false)
        if filter.is_a?(DataCycleCore::Filter::Search)
          filter_query = Arel.sql(filter.select(:id).except(:order).to_sql)
        elsif (stored_filter = DataCycleCore::StoredFilter.find_by(id: filter))
          filter_query = Arel.sql(stored_filter.apply.select(:id).except(:order).to_sql)
        elsif (collection = DataCycleCore::WatchList.find_by(id: filter))
          filter_query = Arel.sql(collection.watch_list_data_hashes.select(:hashable_id).except(:order).to_sql)
        else # in case filter is array of thing_ids
          filter_query = Array.wrap(filter)
        end

        thing_id = :content_a_id
        related_to_id = :content_b_id
        thing_id, related_to_id = related_to_id, thing_id if inverse
        relation_name = inverse ? :relation_b : :relation_a

        sub_select = content_content[thing_id].eq(thing[:id])
                                              .and(content_content[related_to_id].in(filter_query))

        sub_select = sub_select.and(content_content[relation_name].eq(name)) if name.present?

        Arel::SelectManager.new
                           .from(content_content)
                           .where(sub_select)
      end

      ##
      # This is the core functionality for the new bi-directional graph filter
      # Params:
      # +filter+:: Base-Filter / Filter, based on which the graph-filter shall operate. Could be: StoredFilter, WatchList, ...
      # +relation+: OPTIONAL: Restriction for relation name - default: nil (no restriction)
      # +class_aliases+:: OPTIONAL - list of classification aliases that shall be applied instead of relation
      # +direction_a_b+:: OPTIONAL - DEFAULTS to FALSE ( B -> A ) - Tell the graph Filter in which direction it shall work.
      #  Direction A -> B: Return all linked items B of the base filter's resulting items A
      #  Direction B -> A (related_to): Return items A that have a linked item b that can be found in the results of the base filter

      def related_to_any(name = nil, inverse = false)
        thing_id = :content_a_id
        thing_id = :content_b_id if inverse

        sub_select = content_content[thing_id].eq(thing[:id])
        sub_select = sub_select.and(content_content[:relation_a].eq(name)) if name.present?

        Arel::SelectManager.new
          .from(content_content)
          .where(sub_select)
      end

      def default_query
        query = DataCycleCore::Thing.default_scoped
        query = query.where.not(content_type: 'embedded') unless @include_embedded
        query = query.order(boost: :desc, updated_at: :desc, id: :desc)
        query = query.where(DataCycleCore::Search.select(1).where('searches.content_data_id = things.id').where(locale: @locale).arel.exists) if @locale.present?

        query
      end
    end
  end
end
