# frozen_string_literal: true

module DataCycleCore
  module Import
    class FilterObject
      attr_reader :locale, :source_filter
      attr_accessor :mongo_item

      FILTER_METHODS = [
        :with_locale,
        :with_deleted,
        :without_deleted,
        :without_archived,
        :with_updated_since,
        :with_deleted_since,
        :with_external_id
      ].freeze

      def initialize(source_filter, locale, mongo_item, current_binding, filters = [])
        @locale = locale
        @source_filter = dup_source_filter(source_filter)
        @current_binding = current_binding
        @mongo_item = mongo_item
        @filters = filters.map { |v| Array.wrap(v) }

        add_filter!(:with_locale) if @locale.present?
      end

      def source_filter=(filter_hash)
        @source_filter = dup_source_filter(filter_hash)
      end

      FILTER_METHODS.each do |method_name|
        define_method(method_name) do |*args|
          add_filter(method_name, *args)
        end
      end

      def legacy_source_filter
        evaluated_filter.reduce(&:reverse_merge).deep_symbolize_keys.with_indifferent_access
      end

      def query
        raise '@mongo_item is required for query!' if @mongo_item.nil?

        return @mongo_item.all if @source_filter.blank? && @filters.blank?

        evaluated_filter.reduce(@mongo_item) do |query, filter|
          query.where(filter.with_indifferent_access)
        end
      end

      def except(*filters)
        to_exclude = Array.wrap(filters).map do |v|
          f = Array.wrap(v)
          f[0] = filter_key(f[0])
          f
        end

        new_filters = @filters.reject { |f| to_exclude.any? { |e| e == f || (e.one? && e[0] == f[0]) } }

        self.class.new(@source_filter, @locale, @mongo_item, @current_binding, new_filters)
      end

      private

      def dup_source_filter(source_filter)
        Array.wrap(source_filter.presence&.deep_dup).map(&:with_indifferent_access)
      end

      def filter_key(filter_name)
        return nil if filter_name.blank?

        :"#{filter_name}_filter"
      end

      def add_filter(filter_name, *values)
        filter_key = filter_key(filter_name)
        return self if filters_include?(filter_key, *values)

        new_filters = @filters + [[filter_key, *values]]
        self.class.new(@source_filter, @locale, @mongo_item, @current_binding, new_filters)
      end

      def add_filter!(filter_name, *values)
        filter_key = filter_key(filter_name)
        return self if filters_include?(filter_key, *values)

        @filters << [filter_key, *values]
        self
      end

      def filters_include?(filter_key, *values)
        return true if filter_key.blank?

        @filters.any? { |v| v[0] == filter_key.to_sym && v[1..] == values }
      end

      def evaluated_filter
        I18n.with_locale(@locale) do
          evaluated = @source_filter.filter_map do |filter|
            next if filter.blank?

            filter.with_evaluated_values(@current_binding)
          end

          @filters.each do |filter|
            evaluated << send(filter[0], *filter[1..])
          end

          evaluated
        end
      end

      def with_locale_filter
        { "dump.#{@locale}" => { '$exists' => true } }
      end

      def deleted_filter(exists)
        return { 'dump.deleted_at' => { '$exists' => exists } } if @locale.blank?
        { "dump.#{@locale}.deleted_at" => { '$exists' => exists } }
      end

      def with_deleted_filter
        deleted_filter(true)
      end

      def without_deleted_filter
        deleted_filter(false)
      end

      def archived_filter(exists)
        return { 'dump.archived_at' => { '$exists' => exists } } if @locale.blank?
        { "dump.#{@locale}.archived_at" => { '$exists' => exists } }
      end

      def with_archived_filter
        archived_filter(true)
      end

      def without_archived_filter
        archived_filter(false)
      end

      def with_updated_since_filter(timestamp)
        return { 'updated_at' => { '$gte' => timestamp } } if @locale.blank?

        {
          '$or' => [
            { 'updated_at' => { '$gte' => timestamp } },
            { "dump.#{@locale}.updated_at" => { '$gte' => timestamp } }
          ]
        }
      end

      def with_deleted_since_filter(timestamp)
        return { 'dump.deleted_at' => { '$gte' => timestamp } } if @locale.blank?
        { "dump.#{@locale}.deleted_at" => { '$gte' => timestamp } }
      end

      def with_external_id_filter(external_id)
        { 'external_id' => external_id }
      end
    end
  end
end
