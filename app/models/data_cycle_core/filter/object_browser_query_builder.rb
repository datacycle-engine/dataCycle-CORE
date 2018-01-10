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
            # raise @query.count.inspect
            # @query =
            #   joins(:content_search_all, :translations).
            #   where(search[:content_data_type].eq(quoted('DataCycleCore::CreativeWork'))).
            #   where(search[:data_type].eq(quoted('Bild')))
          when @type == 'video'
            @query = @query.where(content_data_type: DataCycleCore::CreativeWork)
          # @query = DataCycleCore::CreativeWork.
          #     joins(:content_search_all, :translations).
          #     where(search[:content_data_type].eq(quoted('DataCycleCore::CreativeWork'))).
          #     where(search[:data_type].eq(quoted('Video')))
          when @type == 'person'
            @query = @query.where(content_data_type: DataCycleCore::Person)
          # @query = DataCycleCore::Person.
          #     joins(:content_search_all, :translations).
          #     where(search[:content_data_type].eq(quoted('DataCycleCore::Person')))
          when @type == 'place'
            @query = @query.where(content_data_type: DataCycleCore::Place)
            # @query = DataCycleCore::Place.
            #     joins(:content_search_all, :translations).
            #     where(place_translation[:locale].eq(quoted(@locale))).
            #     where(search[:content_data_type].eq(quoted('DataCycleCore::Place'))).
            #     where(place[:metadata].not_eq(nil).and(place_translation[:name].not_eq(nil)))
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
