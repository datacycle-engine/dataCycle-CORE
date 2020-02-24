# frozen_string_literal: true

module DataCycleCore
  module Filter
    class Search < QueryBuilder
      include DataCycleCore::Filter::Common::Configurable
      include DataCycleCore::Filter::Common::Advanced
      include DataCycleCore::Filter::Common::ClassificationMapping

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

      def exclude_templates_embedded
        reflect(
          @query.where(template: false).where.not(content_type: 'embedded')
        )
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

      def schedule_search(from, to, relation)
        return self if relation.blank? || (from.blank? && to.blank?)
        @joined_schedule = true

        rdates = Arel::SelectManager.new.project('event_date').from(Arel::Nodes::SqlLiteral.new('unnest(schedules.rdate) AS event_date'))
        occurrences = Arel::SelectManager.new.project('event_date').from(Arel::Nodes::SqlLiteral.new('unnest(get_occurrences(schedules.rrule::rrule, schedules.dtstart)) AS event_date'))
        exdates = Arel::SelectManager.new.project('event_date').from(Arel::Nodes::SqlLiteral.new('unnest(schedules.exdate) AS event_date'))
        from_node = from.blank? ? Arel::Nodes::SqlLiteral.new('NULL') : cast_tstz(from)
        to_node = to.blank? ? Arel::Nodes::SqlLiteral.new('NULL') : cast_tstz(to)

        reflect(
          @query
            .left_outer_joins(:scheduled_data)
            .where(in_json(thing[:schema], 'schema_type').eq(Arel::Nodes.build_quoted('Event')))
            .where(
              overlap(tstzrange(from_node, to_node), tstzrange(thing[:start_date], thing[:end_date]))
              .or(
                schedule[:relation].eq(Arel::Nodes.build_quoted(relation))
                .and(overlap(tstzrange(from_node, to_node), tstzrange(schedule[:dtstart], schedule[:dtend])))
                .and(in_range(tstzrange(from_node, to_node), any(Arel::Nodes::Except.new(rdates.union(occurrences), exdates))))
              )
            )
        )
      end

      def in_validity_period(current_date = Time.zone.now)
        reflect(
          @query.where(in_range(thing[:validity_range], cast_tstz(current_date)))
        )
      end

      def external_source(ids = nil)
        return self if ids.blank?

        reflect(
          @query.where(thing[:external_source_id].in(ids))
        )
      end

      def not_external_source(ids = nil)
        return self if ids.blank?

        reflect(
          @query.where(thing[:external_source_id].not_in(ids).or(thing[:external_source_id].eq(nil)))
        )
      end

      def without_external_source
        reflect(
          @query.where(thing[:external_source_id].eq(nil))
        )
      end

      def external_system(ids = nil)
        return self if ids.blank?

        reflect(
          @query.where(external_system_sync.where(external_system_sync[:external_system_id].in(ids).and(external_system_sync[:syncable_id].eq(thing[:id]))).exists)
        )
      end

      def subscribed_user_id(id = nil)
        return self if id.blank?

        reflect(
          @query.where(subscription.where(subscription[:subscribable_id].eq(thing[:id]).and(subscription[:user_id].eq(id))).exists)
        )
      end

      def with_content_ids(ids = nil)
        return self if ids.blank?

        reflect(
          @query.where(thing[:id].in(ids))
        )
      end

      def not_external_system(ids = nil)
        return self if ids.blank?

        reflect(
          @query.where(external_system_sync.where(external_system_sync[:external_system_id].in(ids).and(external_system_sync[:syncable_id].eq(thing[:id]))).exists.not)
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

      def event_end_time(time)
        time = DataCycleCore::MasterData::DataConverter.string_to_datetime(time)
        reflect(
          @query.where(thing[:start_date].lteq(Arel::Nodes.build_quoted(time.iso8601)))
        )
      end

      def event_from_time(time)
        time = DataCycleCore::MasterData::DataConverter.string_to_datetime(time)
        reflect(
          @query.where(thing[:end_date].gteq(Arel::Nodes.build_quoted(time.iso8601)))
        )
      end

      def sort_by_proximity(date = Time.zone.now)
        reflect(
          @query.reorder(
            absolute_date_diff(thing[:end_date], Arel::Nodes.build_quoted(date.iso8601)),
            absolute_date_diff(thing[:start_date], Arel::Nodes.build_quoted(date.iso8601)),
            thing[:start_date]
          )
        )
      end

      def within_box(sw_lon, sw_lat, ne_lon, ne_lat)
        return self if sw_lon.blank? || sw_lat.blank? || ne_lon.blank? || ne_lat.blank?

        reflect(
          @query.where(contains(thing[:location], get_box(get_point(sw_lon, sw_lat), get_point(ne_lon, ne_lat))).eq('true'))
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

      def classification_alias_ids(ids = nil)
        return self if ids.blank?

        # reflect(@query.with_classification_alias_ids(ids))

        ids = DataCycleCore::ClassificationAlias.where(id: ids).with_descendants.select(:id).arel

        reflect(
          @query.where(
            join_classification_alias_on_classification_content.where(classification_content[:content_data_id].eq(thing[:id]).and(classification_alias[:id].in(ids))).exists
          )
        )
      end

      def not_classification_alias_ids(ids = nil)
        return self if ids.blank?

        reflect(@query.without_classification_alias_ids(ids))
      end

      def date_range(d = nil, attribute_path = nil)
        return self unless d.is_a?(Hash) && d.stringify_keys!.any? { |_, v| v.present? } && attribute_path.present?

        date_range = "[#{d&.dig('from')&.to_s},#{d&.dig('until')&.to_s}]"
        query_string = Thing.send(:sanitize_sql_for_conditions, ["?::daterange @> (things.#{attribute_path})::date", date_range])

        reflect(
          @query.where(query_string)
        )
      end

      def not_date_range(d = nil, attribute_path = nil)
        return self unless d.is_a?(Hash) && d.stringify_keys!.any? { |_, v| v.present? } && attribute_path.present?

        date_range = "[#{d&.dig('from')&.to_s},#{d&.dig('until')&.to_s}]"
        query_string = Thing.send(:sanitize_sql_for_conditions, ["?::daterange @> (things.#{attribute_path})::date", date_range])

        reflect(
          @query.where.not(query_string)
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

      def geo_radius(values)
        return self if values&.dig('lon').blank? || values&.dig('lat').blank? || values&.dig('distance').blank?

        reflect(
          @query.where(st_dwithin(cast_geography(thing[:location]), cast_geography(st_setsrid(st_makepoint(values&.dig('lon'), values&.dig('lat')), 4326)), values&.dig('distance').to_i))
        )
      end

      def geo_within_classification(ids)
        return self if ids.blank?

        contains_queries = []
        ids.each do |id|
          sub_query = Arel::SelectManager.new
            .project(classification_polygon[:geom])
            .from(classification_polygon)
            .where(classification_polygon[:classification_alias_id].eq(id))

          contains_queries << st_contains(sub_query, st_transform(thing[:location], 3035))
        end

        reflect(
          @query.where(contains_queries.reduce(:or))
        )
      end

      def not_geo_within_classification(ids)
        return self if ids.blank?

        contains_queries = []
        ids.each do |id|
          sub_query = Arel::SelectManager.new
            .project(classification_polygon[:geom])
            .from(classification_polygon)
            .where(classification_polygon[:classification_alias_id].eq(id))

          contains_queries << st_disjoint(sub_query, st_transform(thing[:location], 3035))
        end

        reflect(
          @query.where(contains_queries.reduce(:or))
        )
      end

      def validity_period(d = nil)
        return self unless d.is_a?(Hash) && d.stringify_keys!.any? { |_, v| v.present? }

        date_range = "[#{d&.dig('from')&.to_datetime&.noon&.to_s},#{d&.dig('until')&.to_datetime&.noon&.to_s}]"
        query_string = Thing.send(:sanitize_sql_for_conditions, ['things.validity_range @> ?::tstzrange', date_range])
        reflect(
          @query.where(query_string)
        )
      end

      def not_validity_period(d = nil)
        return self unless d.is_a?(Hash) && d.stringify_keys!.any? { |_, v| v.present? }

        date_range = "[#{d&.dig('from')&.to_datetime&.noon&.to_s},#{d&.dig('until')&.to_datetime&.noon&.to_s}]"
        query_string = Thing.send(:sanitize_sql_for_conditions, ['things.validity_range @> ?::tstzrange', date_range])

        reflect(
          @query.where.not(query_string)
        )
      end

      def classification_tree_ids(ids = nil)
        return self if ids.blank?

        reflect(
          @query.where(
            join_classification_trees_on_classification_content.where(classification_content[:content_data_id].eq(thing[:id]).and(classification_tree[:classification_tree_label_id].in(ids))).exists
          )
        )
      end

      def not_classification_tree_ids(ids = nil)
        return self if ids.blank?

        reflect(
          @query.where(
            thing[:id].not_in(
              join_classification_trees.where(classification_tree[:classification_tree_label_id].in(ids))
            )
          )
        )
      end

      def with_classification_alias_ids_without_recursion(ids = nil)
        return self if ids.blank?

        reflect(
          @query.where(
            join_classification_alias_on_classification_content.where(classification_content[:content_data_id].eq(thing[:id]).and(classification_alias[:id].in(ids))).exists
          )
        )
      end

      def with_classification_aliases(tree_name, *aliases)
        sub_query = DataCycleCore::Thing
          .joins(:classification_aliases)
          .merge(
            DataCycleCore::ClassificationAlias
              .for_tree(tree_name)
              .with_internal_name(aliases)
              .with_descendants
          )

        reflect(
          @query.where(id: sub_query)
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

      private

      def join_classification_alias
        Arel::SelectManager.new
          .project(thing[:id])
          .from(thing)
          .join(classification_content)
          .on(thing[:id].eq(classification_content[:content_data_id]))
          .join(classification)
          .on(classification_content[:classification_id].eq(classification[:id]))
          .join(classification_group)
          .on(classification[:id].eq(classification_group[:classification_id]))
          .join(classification_alias)
          .on(classification_group[:classification_alias_id].eq(classification_alias[:id]))
          .where(
            classification[:deleted_at].eq(nil)
              .and(classification_group[:deleted_at].eq(nil))
              .and(classification_alias[:deleted_at].eq(nil))
          )
      end

      def join_classification_trees
        Arel::SelectManager.new
          .project(thing[:id])
          .from(thing)
          .join(classification_content)
          .on(thing[:id].eq(classification_content[:content_data_id]))
          .join(classification)
          .on(classification_content[:classification_id].eq(classification[:id]))
          .join(classification_group)
          .on(classification[:id].eq(classification_group[:classification_id]))
          .join(classification_alias)
          .on(classification_group[:classification_alias_id].eq(classification_alias[:id]))
          .join(classification_tree)
          .on(classification_alias[:id].eq(classification_tree[:classification_alias_id]))
          .where(
            classification[:deleted_at].eq(nil)
              .and(classification_group[:deleted_at].eq(nil))
              .and(classification_alias[:deleted_at].eq(nil))
          )
      end

      def join_classification_trees_on_classification_content
        Arel::SelectManager.new
          .from(classification_content)
          .join(classification)
          .on(classification_content[:classification_id].eq(classification[:id]))
          .join(classification_group)
          .on(classification[:id].eq(classification_group[:classification_id]))
          .join(classification_alias)
          .on(classification_group[:classification_alias_id].eq(classification_alias[:id]))
          .join(classification_tree)
          .on(classification_alias[:id].eq(classification_tree[:classification_alias_id]))
          .where(
            classification[:deleted_at].eq(nil)
              .and(classification_group[:deleted_at].eq(nil))
              .and(classification_alias[:deleted_at].eq(nil))
          )
      end

      def join_classification_alias_on_classification_content
        Arel::SelectManager.new
          .from(classification_content)
          .join(classification)
          .on(classification_content[:classification_id].eq(classification[:id]))
          .join(classification_group)
          .on(classification[:id].eq(classification_group[:classification_id]))
          .join(classification_alias)
          .on(classification_group[:classification_alias_id].eq(classification_alias[:id]))
          .where(
            classification[:deleted_at].eq(nil)
              .and(classification_group[:deleted_at].eq(nil))
              .and(classification_alias[:deleted_at].eq(nil))
          )
      end

      def classification_content
        DataCycleCore::ClassificationContent.arel_table
      end

      def classification
        Classification.arel_table
      end

      def classification_tree
        ClassificationTree.arel_table
      end

      def classification_group
        ClassificationGroup.arel_table
      end

      def classification_alias
        ClassificationAlias.arel_table
      end

      def watch_list_data_hash
        DataCycleCore::WatchListDataHash.arel_table
      end

      def content_content
        DataCycleCore::ContentContent.arel_table
      end

      def search
        DataCycleCore::Search.arel_table
      end

      def schedule
        DataCycleCore::Schedule.arel_table
      end

      def thing
        DataCycleCore::Thing.arel_table
      end

      def classification_polygon
        DataCycleCore::ClassificationPolygon.arel_table
      end

      def duplicate_candidate
        DataCycleCore::Thing::DuplicateCandidate.arel_table
      end

      def external_system_sync
        DataCycleCore::ExternalSystemSync.arel_table
      end

      def subscription
        DataCycleCore::Subscription.arel_table
      end
    end
  end
end
