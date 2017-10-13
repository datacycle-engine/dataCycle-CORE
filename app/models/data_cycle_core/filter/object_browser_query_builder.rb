module DataCycleCore
  module Filter
    class ObjectBrowserQueryBuilder < Search

      def initialize(locale = 'de', type = 'image', query = nil)
        @locale = locale
        @type = type
        @query = query
        if @query.nil?
          case
          when @type == 'image'
            @query = DataCycleCore::CreativeWork.
              joins(:content_search_all, :translations).
              where(search[:content_data_type].eq(quoted('DataCycleCore::CreativeWork'))).
              where(search[:data_type].eq(quoted('Bild')))
          when @type == 'video'
            @query = DataCycleCore::CreativeWork.
              joins(:content_search_all, :translations).
              where(search[:content_data_type].eq(quoted('DataCycleCore::CreativeWork'))).
              where(search[:data_type].eq(quoted('Video')))
          when @type == 'person'
            @query = DataCycleCore::Person.
              joins(:content_search_all, :translations).
              where(search[:content_data_type].eq(quoted('DataCycleCore::Person')))
          when @type == 'place'
            @query = DataCycleCore::Place.
              joins(:content_search_all, :translations).
              where(search[:content_data_type].eq(quoted('DataCycleCore::Place'))).
              where(place[:metadata].not_eq(nil).and(place_translation[:name].not_eq(nil)))
          end
          @query = @query.where(search[:locale].eq(quoted(@locale))).includes(:translations)
        end
      end

    private
    # define Arel-tables

      def place
        DataCycleCore::Place.arel_table
      end

      def place_translation
        DataCycleCore::Place::Translation.arel_table
      end

      def reflect(query)
        self.class.new(@locale, @type, query)
      end

    end
  end
end
