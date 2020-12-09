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
      include DataCycleCore::Filter::Common::Union
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

        subquery = related_to_query(filter, name)
        return self if subquery.nil?

        reflect(
          @query.where(subquery.exists)
        )
      end

      def not_relation_filter(filter = nil, name = nil)
        return self if name.blank?
        return self if filter.blank?

        subquery = related_to_query(filter, name)
        return self if subquery.nil?

        reflect(
          @query.where.not(subquery.exists)
        )
      end

      def related_to(filter_id = nil)
        return self if filter_id.blank?

        subquery = related_to_query(filter_id)
        return self if subquery.nil?

        reflect(
          @query.where(subquery.exists)
        )
      end

      def not_related_to(filter_id = nil)
        return self if filter_id.blank?

        subquery = related_to_query(filter_id)
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

      def related_to_query(filter, name = nil)
        if filter.is_a?(DataCycleCore::Filter::Search)
          filter_query = filter.select(:id).except(:order)
        elsif (stored_filter = DataCycleCore::StoredFilter.find_by(id: filter))
          filter_query = stored_filter.apply.select(:id).except(:order)
        elsif (collection = DataCycleCore::WatchList.find_by(id: filter))
          filter_query = collection.watch_list_data_hashes.select(:hashable_id).except(:order)
        else
          return
        end

        sub_select = content_content[:content_a_id].eq(thing[:id])
          .and(content_content[:content_b_id].in(Arel.sql(filter_query.to_sql)))

        sub_select = sub_select.and(content_content[:relation_a].eq(name)) if name.present?

        Arel::SelectManager.new
          .from(content_content)
          .where(sub_select)
      end

      def default_query
        query = DataCycleCore::Thing.where(template: false)
        query = query.where.not(content_type: 'embedded') unless @include_embedded
        query = query.order(boost: :desc, updated_at: :desc, id: :desc)
        query = query.where(DataCycleCore::Search.select(1).where('searches.content_data_id = things.id').where(locale: @locale).arel.exists) if @locale.present?
        query
      end
    end
  end
end
