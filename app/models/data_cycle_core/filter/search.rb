# frozen_string_literal: true

module DataCycleCore
  module Filter
    class Search < QueryBuilder
      include Common::Advanced
      include Common::Classification
      include Common::Date
      include Common::External
      include Common::Id
      include Common::Fulltext
      include Common::Typeahead
      include Common::Geo
      include Common::Union
      include Common::User
      include Common::Graph
      include Common::Aggregate
      include Sortable
      include DataCycleCore::Common::TsQueryHelpers

      def initialize(locale: ['de'], query: nil, include_embedded: false, thing_alias: nil)
        @locale = locale
        @include_embedded = include_embedded
        @is_root_query = thing_alias.nil?
        @thing_alias = thing_alias || 'things'
        @thing_alias = thing.alias(@thing_alias) if @thing_alias.is_a?(String)
        @base_query = DataCycleCore::Thing.all
        @query = query || default_query
      end

      def content_includes
        if DataCycleCore.filter_strategy == 'joins'
          @base_query = @base_query.includes(
            :translations,
            :external_source,
            :external_systems,
            :parent,
            :primary_classification_aliases,
            classification_aliases: [:classification_alias_path, :classification_tree_label]
          )
        else
          @query = @query.includes(
            :translations,
            :external_source,
            :external_systems,
            :parent,
            :primary_classification_aliases,
            classification_aliases: [:classification_alias_path, :classification_tree_label]
          )
        end

        self
      end

      def subscribed_user_id(id = nil)
        return self if id.blank?

        if DataCycleCore.filter_strategy == 'joins'
          s_alias = "s_#{SecureRandom.hex(5)}"
          reflect(
            @query.joins(
              sanitize_sql(
                [
                  "INNER JOIN subscriptions #{s_alias} ON #{s_alias}.subscribable_id = #{thing_alias.right}.id AND #{s_alias}.user_id IN (?)",
                  id
                ]
              )
            )
          )
        else
          reflect(
            @query.where(
              subscription.where(subscription[:subscribable_id].eq(thing_alias[:id]).and(subscription[:user_id].eq(id))).exists
            )
          )
        end
      end

      def updated_since_flat(updated_at = nil)
        return self if updated_at.blank?

        reflect(
          @query.where(thing_alias[:updated_at].gteq(quoted(updated_at)))
        )
      end

      def updated_since(updated_at = nil, iteration_depth = 5)
        return self if updated_at.blank?

        updated_since = updated_at
        t_alias = thing_alias.right

        raw_sql = <<-SQL.squish
          WITH RECURSIVE content_dependencies AS (
            SELECT ARRAY["#{t_alias}"."id"] "content_ids"
              FROM things AS t
              WHERE t.id = "#{t_alias}"."id"
              AND t.updated_at >= ?
            UNION
            SELECT ARRAY[content_content_links.content_b_id, content_content_links.content_a_id] "content_ids"
              FROM content_content_links
              JOIN things AS t ON t.id = content_content_links.content_b_id
              WHERE content_content_links.content_a_id = "#{t_alias}"."id"
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
          ) SELECT 1 FROM content_dependencies WHERE content_ids[array_length(content_ids, 1)] = "#{t_alias}"."id"
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

        query_string = ActiveRecord::Base.send(:sanitize_sql_for_conditions, [sql, {attribute_path: 'schema_type', type:}])

        reflect(
          @query.left_outer_joins(:thing_template).where(Arel.sql(query_string))
        )
      end

      def watch_list_id(id = nil)
        return self if id.blank?

        if DataCycleCore.filter_strategy == 'joins'
          wldh_alias = "wldh_#{SecureRandom.hex(5)}"
          reflect(
            @query.joins(
              sanitize_sql(
                [
                  "INNER JOIN watch_list_data_hashes #{wldh_alias} ON #{wldh_alias}.thing_id = #{thing_alias.right}.id AND #{wldh_alias}.watch_list_id IN (?)",
                  id
                ]
              )
            )
          )
        else
          reflect(
            @query.where(
              watch_list_data_hash.where(watch_list_data_hash[:thing_id].eq(thing_alias[:id]).and(watch_list_data_hash[:watch_list_id].eq(id))).exists
            )
          )
        end
      end

      def part_of(id = nil)
        return self if id.blank?

        reflect(
          @query.where(thing_alias[:is_part_of].eq(id))
        )
      end

      def relation(name = nil)
        return self if name.blank?

        if DataCycleCore.filter_strategy == 'joins'
          cc_alias = "cc_#{SecureRandom.hex(5)}"
          reflect(
            @query.joins(
              sanitize_sql(
                [
                  "INNER JOIN content_contents #{cc_alias} ON #{cc_alias}.content_a_id = #{thing_alias.right}.id AND #{cc_alias}.relation_a IN (?)",
                  name
                ]
              )
            )
          )
        else
          reflect(
            @query.where(content_content.where(content_content[:content_a_id].eq(thing_alias[:id]).and(content_content[:relation_a].eq(name))).exists)
          )
        end
      end

      def like_relation_filter(filter = nil, name = nil)
        return self if name.blank? || filter.blank?

        if DataCycleCore.filter_strategy == 'joins'
          reflect(
            related_to_joins_query(filter, name)
          )
        else
          subquery = related_to_query(filter, name)
          return self if subquery.nil?

          reflect(
            @query.where(subquery.exists)
          )
        end
      end

      def not_like_relation_filter(filter = nil, name = nil)
        return self if name.blank? || filter.blank?

        if DataCycleCore.filter_strategy == 'joins'
          reflect(
            not_related_to_joins_query(filter, name)
          )
        else
          subquery = related_to_query(filter, name)
          return self if subquery.nil?

          reflect(
            @query.where.not(subquery.exists)
          )
        end
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

        if DataCycleCore.filter_strategy == 'joins'
          reflect(
            related_to_any_joins_query(name, inverse)
          )
        else
          subquery = related_to_any(name, inverse)
          return self if subquery.nil?

          reflect(
            @query.where(subquery.project(1).exists)
          )
        end
      end

      def not_exists_relation_filter(name = nil, inverse = false)
        return self if name.blank?

        if DataCycleCore.filter_strategy == 'joins'
          reflect(
            not_related_to_any_joins_query(name, inverse)
          )
        else
          subquery = related_to_any(name, inverse)
          return self if subquery.nil?

          reflect(
            @query.where.not(subquery.project(1).exists)
          )
        end
      end

      def relation_filter(filter = nil, name = nil)
        return self if name.blank? || filter.blank?

        if DataCycleCore.filter_strategy == 'joins'
          reflect(
            related_to_joins_query(filter, name)
          )
        else
          subquery = related_to_query(filter, name)
          return self if subquery.nil?

          reflect(
            @query.where(subquery.exists)
          )
        end
      end

      def not_relation_filter(filter = nil, name = nil)
        return self if name.blank? || filter.blank?

        if DataCycleCore.filter_strategy == 'joins'
          reflect(
            not_related_to_joins_query(filter, name)
          )
        else
          subquery = related_to_query(filter, name)
          return self if subquery.nil?

          reflect(
            @query.where.not(subquery.exists)
          )
        end
      end

      def relation_filter_inv(filter = nil, name = nil)
        return self if name.blank? || filter.blank?

        if DataCycleCore.filter_strategy == 'joins'
          reflect(
            related_to_joins_query(filter, name, true)
          )
        else
          subquery = related_to_query(filter, name, true)
          return self if subquery.nil?

          reflect(
            @query.where(subquery.exists)
          )
        end
      end

      def not_relation_filter_inv(filter = nil, name = nil)
        return self if name.blank? || filter.blank?

        if DataCycleCore.filter_strategy == 'joins'
          reflect(
            not_related_to_joins_query(filter, name, true)
          )
        else
          subquery = related_to_query(filter, name, true)
          return self if subquery.nil?

          reflect(
            @query.where.not(subquery.exists)
          )
        end
      end

      def related_to(filter_id = nil)
        return self if filter_id.blank?

        if DataCycleCore.filter_strategy == 'joins'
          reflect(
            related_to_joins_query(filter_id, nil, true)
          )
        else
          subquery = related_to_query(filter_id, nil, true)
          return self if subquery.nil?

          reflect(
            @query.where(subquery.exists)
          )
        end
      end

      def not_related_to(filter_id = nil)
        return self if filter_id.blank?

        if DataCycleCore.filter_strategy == 'joins'
          reflect(
            not_related_to_joins_query(filter_id, nil, true)
          )
        else
          subquery = related_to_query(filter_id, nil, true)
          return self if subquery.nil?

          reflect(
            @query.where.not(subquery.exists)
          )
        end
      end

      def boolean(value, filter_method)
        if respond_to?(filter_method)
          send(filter_method, value)
        else
          self
        end
      end

      def duplicate_candidates(value, score = nil)
        if DataCycleCore.filter_strategy == 'joins'
          dc_alias = "dc_#{SecureRandom.hex(5)}"
          if value.to_s == 'true'
            joins_query = ["INNER JOIN duplicate_candidates #{dc_alias} ON #{dc_alias}.duplicate_id = #{thing_alias.right}.id AND #{dc_alias}.false_positive = ?", false]

            if score.present?
              joins_query[0] += " AND #{dc_alias}.score >= ?"
              joins_query << score.to_i
            end

            reflect(@query.joins(sanitize_sql(joins_query)))
          else
            joins_query = ["LEFT OUTER JOIN duplicate_candidates #{dc_alias} ON #{dc_alias}.duplicate_id = #{thing_alias.right}.id AND #{dc_alias}.false_positive = ?", false]

            if score.present?
              joins_query[0] += " AND #{dc_alias}.score >= ?"
              joins_query << score.to_i
            end

            reflect(@query.joins(sanitize_sql(joins_query))).where("#{dc_alias}.id IS NULL")
          end
        else
          sub_query = duplicate_candidate[:duplicate_id].eq(thing_alias[:id]).and(duplicate_candidate[:false_positive].eq(false))
          sub_query = sub_query.and(duplicate_candidate[:score].gteq(score.to_i)) if score.present?

          if value.to_s == 'true'
            reflect(
              @query.where(duplicate_candidate.project(1).where(sub_query).exists)
            )
          else
            reflect(
              @query.where(duplicate_candidate.project(1).where(sub_query).exists.not)
            )
          end
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
          @query.where(thing_alias[:template_name].in(Array.wrap(names)))
        )
      end

      def exclude_ids(ids)
        return self if ids.blank?

        reflect(
          @query.where.not(thing_alias[:id].in(Array.wrap(ids)))
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

      def related_to_filter_query(filter)
        if filter.is_a?(Search)
          Arel.sql(filter.select(:id).except(:order).to_sql)
        elsif (stored_filter = DataCycleCore::StoredFilter.find_by(id: filter))
          Arel.sql(stored_filter.things.select(:id).except(:order).to_sql)
        elsif (collection = DataCycleCore::WatchList.find_by(id: filter))
          Arel.sql(collection.watch_list_data_hashes.select(:thing_id).except(:order).to_sql)
        else # in case filter is array of thing_ids
          Array.wrap(filter)
        end
      end

      def related_to_query(filter, name = nil, inverse = false)
        filter_query = related_to_filter_query(filter)
        thing_id = :content_a_id
        related_to_id = :content_b_id
        thing_id, related_to_id = related_to_id, thing_id if inverse
        relation_name = inverse ? :relation_b : :relation_a

        sub_select = content_content[thing_id].eq(thing_alias[:id])
          .and(content_content[related_to_id].in(filter_query))

        sub_select = sub_select.and(content_content[relation_name].eq(name)) if name.present?

        Arel::SelectManager.new
          .from(content_content)
          .where(sub_select)
      end

      def related_to_joins_query(filter, relation = nil, inverse = false)
        filter_query = related_to_filter_query(filter)
        thing_id = :content_a_id
        related_to_id = :content_b_id
        thing_id, related_to_id = related_to_id, thing_id if inverse
        relation_name = inverse ? :relation_b : :relation_a

        cc_alias = "cc_#{SecureRandom.hex(5)}"
        joins_query = ["INNER JOIN content_contents #{cc_alias} ON #{cc_alias}.#{thing_id} = #{thing_alias.right}.id AND #{cc_alias}.#{related_to_id} IN (?)", filter_query]

        if relation.present?
          joins_query[0] += " AND #{cc_alias}.#{relation_name} IN (?)"
          joins_query << relation
        end

        @query.joins(sanitize_sql(joins_query))
      end

      def not_related_to_joins_query(filter, relation = nil, inverse = false)
        filter_query = related_to_filter_query(filter)
        thing_id = :content_a_id
        related_to_id = :content_b_id
        thing_id, related_to_id = related_to_id, thing_id if inverse
        relation_name = inverse ? :relation_b : :relation_a

        cc_alias = "cc_#{SecureRandom.hex(5)}"
        joins_query = ["LEFT OUTER JOIN content_contents #{cc_alias} ON #{cc_alias}.#{thing_id} = #{thing_alias.right}.id AND #{cc_alias}.#{related_to_id} IN (?)", filter_query]

        if relation.present?
          joins_query[0] += " AND #{cc_alias}.#{relation_name} IN (?)"
          joins_query << relation
        end

        @query.joins(sanitize_sql(joins_query)).where("#{cc_alias}.id IS NULL")
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

        sub_select = content_content[thing_id].eq(thing_alias[:id])
        sub_select = sub_select.and(content_content[:relation_a].eq(name)) if name.present?

        Arel::SelectManager.new
          .from(content_content)
          .where(sub_select)
      end

      def related_to_any_joins_query(name = nil, inverse = false)
        thing_id = :content_a_id
        thing_id = :content_b_id if inverse

        cc_alias = "cc_#{SecureRandom.hex(5)}"
        joins_query = ["INNER JOIN content_contents #{cc_alias} ON #{cc_alias}.#{thing_id} = #{thing_alias.right}.id"]

        if name.present?
          joins_query[0] += " AND #{cc_alias}.relation_a IN (?)"
          joins_query << name
        end

        @query.joins(sanitize_sql(joins_query))
      end

      def not_related_to_any_joins_query(name = nil, inverse = false)
        thing_id = :content_a_id
        thing_id = :content_b_id if inverse

        cc_alias = "cc_#{SecureRandom.hex(5)}"
        joins_query = ["LEFT OUTER JOIN content_contents #{cc_alias} ON #{cc_alias}.#{thing_id} = #{thing_alias.right}.id"]

        if name.present?
          joins_query[0] += " AND #{cc_alias}.relation_a IN (?)"
          joins_query << name
        end

        @query.joins(sanitize_sql(joins_query)).where("#{cc_alias}.id IS NULL")
      end

      def default_query
        query = DataCycleCore::Thing.default_scoped
        query = query.from(thing_alias) unless thing_alias.right == 'things'
        query = query.where.not(thing_alias[:content_type].eq('embedded')) unless include_embedded

        if @locale.present?
          query = query.where(
            DataCycleCore::Search
              .select(1)
              .where(search[:content_data_id].eq(thing_alias[:id]))
              .where(locale: @locale)
              .arel
              .exists
          )
        end

        @base_query = @base_query.order(thing_alias[:boost].desc, thing_alias[:updated_at].desc, thing_alias[:id].desc) if is_root_query

        query
      end
    end
  end
end
