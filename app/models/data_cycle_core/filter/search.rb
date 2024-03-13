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
              AND t.updated_at >= ?
            UNION
            SELECT content_content_links.content_b_id || content_dependencies.content_ids "content_ids"
              FROM content_content_links
              JOIN things AS t ON t.id = content_content_links.content_b_id
              JOIN content_dependencies ON content_dependencies.content_ids[1] = content_content_links.content_a_id
              AND content_content_links.content_b_id <> ALL(content_dependencies.content_ids)
              AND t.updated_at >= ?
            WHERE array_length(content_dependencies.content_ids, 1) < ?
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

      def graph_filter(item_a, item_b, filter_id = nil, direction_a_b = true, inverse = false)
        direction_a_b ? item_a : item_b
        direction_a_b ? item_b : item_a

        return unless direction_a_b
        related_to_query(filter_id, nil, inverse)
        # elsif
        #
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
        graph_filter_query(filter, name, inverse, false)

        # if filter.is_a?(DataCycleCore::Filter::Search)
        #   filter_query = Arel.sql(filter.select(:id).except(:order).to_sql)
        # elsif (stored_filter = DataCycleCore::StoredFilter.find_by(id: filter))
        #   filter_query = Arel.sql(stored_filter.apply.select(:id).except(:order).to_sql)
        # elsif (collection = DataCycleCore::WatchList.find_by(id: filter))
        #   filter_query = Arel.sql(collection.watch_list_data_hashes.select(:hashable_id).except(:order).to_sql)
        # else # in case filter is array of thing_ids
        #   filter_query = Array.wrap(filter)
        # end
        #
        # thing_id = :content_a_id
        # related_to_id = :content_b_id
        # thing_id, related_to_id = related_to_id, thing_id if inverse
        # relation_name = inverse ? :relation_b : :relation_a
        #
        # sub_select = content_content[thing_id].eq(thing[:id])
        #                                       .and(content_content[related_to_id].in(filter_query))
        #
        # sub_select = sub_select.and(content_content[relation_name].eq(name)) if name.present?
        #
        # Arel::SelectManager.new
        #                    .from(content_content)
        #                    .where(sub_select)
      end

      ##
      # This is the core functionality for the new bi-directional graph filter
      # Params:
      # +filter+:: Base-Filter / Filter, based on which the graph-filter shall operate. Could be: StoredFilter, WatchList, ...
      # +name+:: TODO: Evaluate if this is still needed later! - Takes a relation_name for which checks shall occur. Currently only content_location and image is supported, should not be needed at all in the end
      # +inverse+:: OPTIONAL - Defaults to FALSE - Tell the graph filter if it should work as an inverse filter or not - ToDo: Evaluate if logic works properly or if it needs adapion - originally copied from related_to filter function
      # +direction_a_b:: OPTIONAL - DEFAULTS to FALSE ( B -> A ) - Tell the graph Filter in which direction it shall work.
      #  Direction A -> B: Return all linked items B of the base filter's resulting items A
      #  Direction B -> A (related_to): Return items A that have a linked item b that can be found in the results of the base filter
      # +target_template+:: More or less the same as 'name' now, but not mapped: ToDo: Re-evaluate what to pass on to the graph filter and update logic accordingly

      def graph_filter_query(filter, name = nil, inverse = false, direction_a_b = false, target_template = nil)
        if filter.is_a?(DataCycleCore::Filter::Search)
          filter_query = Arel.sql(filter.select(:id).except(:order).to_sql)
        elsif (stored_filter = DataCycleCore::StoredFilter.find_by(id: filter))
          filter_query = Arel.sql(stored_filter.apply.select(:id).except(:order).to_sql)
        elsif (collection = DataCycleCore::WatchList.find_by(id: filter))
          filter_query = Arel.sql(collection.watch_list_data_hashes.select(:hashable_id).except(:order).to_sql)
        else # in case filter is array of thing_ids
          filter_query = Array.wrap(filter)
        end

        thing_id = direction_a_b ? :content_a_id : :content_b_id
        related_to_id = direction_a_b ? :content_b_id : :content_a_id
        thing_id, related_to_id = related_to_id, thing_id if inverse

        # TODO: Replace once new filter is properly created and can be enabled in features.yml
        if name == 'content_location'
          target_template = 'Place'
        elsif name == 'image'
          target_template = 'ImageObject'
        end
        # Todo - END

        related_found_things = content_content_link[related_to_id].in(filter_query)

        if target_template.present?
          infix_operation = Arel::Nodes::InfixOperation.new('=', Arel::Nodes.build_quoted(target_template), any(thing_template[:computed_schema_types]))
          target_template_query = Arel::SelectManager.new.from(thing_template).where(infix_operation).project(thing_template[:template_name])
          target_template_things = Arel::SelectManager.new.from(thing).where(thing[:template_name].in(target_template_query)).project(thing[:id])

          related_template_things = content_content_link[related_to_id].in(target_template_things)

          sub_select = content_content_link[thing_id].eq(thing[:id])
                                                     .and(related_found_things)
                                                     .and(related_template_things)
        else
          sub_select = content_content_link[thing_id].eq(thing[:id])
                                                     .and(related_found_things)
        end

        Arel::SelectManager.new
                                    # .from("#{content_content_link.name}, #{thing.name}, #{thing_template.name}")
                                    .from(content_content_link)
                           .where(sub_select)
      end

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
        query = DataCycleCore::Thing
        query = query.where.not(content_type: 'embedded') unless @include_embedded
        query = query.order(boost: :desc, updated_at: :desc, id: :desc)
        query = query.where(DataCycleCore::Search.select(1).where('searches.content_data_id = things.id').where(locale: @locale).arel.exists) if @locale.present?

        query
      end
    end
  end
end
