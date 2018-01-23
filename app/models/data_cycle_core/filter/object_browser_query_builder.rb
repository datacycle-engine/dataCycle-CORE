module DataCycleCore
  module Filter
    class ObjectBrowserQueryBuilder < Search
      def initialize(locale = 'de', type = 'image', query = nil)
        @locale = locale
        @type = type
        @query = query
        if @query.nil?
          @query = super locale, query
          case
            when @type == 'image'
              @query = @query.where(content_data_type: DataCycleCore::CreativeWork)
            when @type == 'video'
              @query = @query.where(content_data_type: DataCycleCore::CreativeWork)
            when @type == 'person'
              @query = @query.where(content_data_type: DataCycleCore::Person)
            when @type == 'place'
              @query = @query.where(content_data_type: DataCycleCore::Place)
          end
        end
      end

      private

      def reflect(query)
        self.class.new(@locale, @type, query)
      end

    end
  end
end
