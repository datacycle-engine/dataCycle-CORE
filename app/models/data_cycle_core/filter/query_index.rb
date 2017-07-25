module DataCycleCore
  module Filter
    class QueryIndex

      attr_accessor :default_per_page

      attr_internal_accessor :limit_value, :offset_value
      @@supported_objects = [
          DataCycleCore::Filter::CreativeWorkQueryBuilder,
          DataCycleCore::Filter::PlaceQueryBuilder,
          DataCycleCore::Filter::PersonQueryBuilder
      ]

      def initialize(query_array = [], limit: nil, offset: nil, language: 'de')
        @language = language
        @default_per_page = 25
        @query_array = query_array
        @limit_value = (limit || default_per_page).to_i
        @offset_value = offset.to_i

        if query_array == []
          @@supported_objects.each do |query_object|
            @query_array.push(query_object.new(@language))
          end
        end
      end

    # extract array_data
      def page_data
        extract(@offset_value, @limit_value)
      end

      def extract(offset, limit)
        fractions = count
        return [] if offset > fractions.sum

        return_array = []
        pos_start = 0

        @query_array.each do |item|
          #puts "get(#{item}, #{pos_start}, #{pos_start + item.count}, #{offset}, #{limit}, #{return_array.size})"
          return_array += get(item, pos_start, pos_start + item.count, offset, limit, return_array.size)
          pos_start += item.count
        end
        return_array
      end

      def get(array_item, pos_start, pos_end, offset, limit, grapped)
        # check for out of bound, or already all items found
        return [] if grapped >= limit || offset > pos_end || pos_start > offset + limit
        start_index = offset < pos_start ? 0 : offset - pos_start
        end_index = offset + (limit-grapped) < pos_end ? limit - grapped : pos_end - offset
        #puts "return(#{start_index}..#{end_index})"
        return array_item.offset(start_index).limit(end_index).to_a
      end

    # delegate query parameter

      def fulltext_search(search_text)
        @query_array.each_index do |index|
          @query_array[index] = @query_array[index].fulltext_search(search_text)
        end
        self.class.new(@query_array, limit: @limit_value, offset: @offset_value, language: @language)
      end

      def with_classification_alias_ids(ids)
        @query_array.each_index do |index|
          @query_array[index] = @query_array[index].with_classification_alias_ids(ids)
        end
        self.class.new(@query_array, limit: @limit_value, offset: @offset_value, language: @language)
      end

      def order(order_hash)
        @query_array.each_index do |index|
          @query_array[index] = @query_array[index].order(order_hash)
        end
        self.class.new(@query_array, limit: @limit_value, offset: @offset_value, language: @language)
      end

    # helper
      def count
        @query_array.map{|query| query.count}
      end

    # kaminari paginate methods
      def total_count
        count.sum
      end

      def page(num = 1)
        offset(@limit_value * ((num = num.to_i - 1) < 0 ? 0 : num))
      end

      def limit(num)
        self.class.new(@query_array, limit: num, offset: @offset_value, language: @language)
      end

      def offset(num)
        self.class.new(@query_array, limit: @limit_value, offset: num, language: @language)
      end

      # Total number of pages
      def total_pages
        (total_count.to_f / @limit_value).ceil
      rescue FloatDomainError
        raise ZeroPerPageOperation, "The number of total pages was incalculable. Perhaps you called .per(0)?"
      end

      def current_page
        offset_without_padding = @offset_value
        offset_without_padding = 0 if offset_without_padding < 0

        (offset_without_padding / @limit_value) + 1
      rescue ZeroDivisionError
        raise ZeroPerPageOperation, "Current page was incalculable. Perhaps you called .per(0)?"
      end

      # Next page number in the collection
      def next_page
        current_page + 1 unless last_page? || out_of_range?
      end

      # Previous page number in the collection
      def prev_page
        current_page - 1 unless first_page? || out_of_range?
      end

      # First page of the collection?
      def first_page?
        current_page == 1
      end

      # Last page of the collection?
      def last_page?
        current_page == total_pages
      end

      # Out of range of the collection?
      def out_of_range?
        current_page > total_pages
      end

    end
  end
end
