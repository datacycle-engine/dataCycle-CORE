module DataCycleCore
  module Filter
    class ObjectBrowserQueryBuilder < Search
      def initialize(locale = 'de', type = 'image', query = nil)
        @locale = locale
        @type = type
        @query = query
        if @query.nil?
          @query = super locale, query
          if @type == 'image'
            @query = @query.where(content_data_type: DataCycleCore::CreativeWork)
          elsif @type == 'video'
            @query = @query.where(content_data_type: DataCycleCore::CreativeWork)
          elsif @type == 'person'
            @query = @query.where(content_data_type: DataCycleCore::Person)
          elsif @type == 'organization'
            @query = @query.where(content_data_type: DataCycleCore::Organization)
          elsif @type == 'place'
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
