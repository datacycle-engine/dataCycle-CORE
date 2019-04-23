# frozen_string_literal: trueA

module DataCycleCore
  module Filter
    class QueryBuilder
      extend Forwardable
      include Enumerable
      include DataCycleCore::Common::ArelBuilder

      attr_reader :query
      def_delegators :@query, :to_a, :to_sql, :each, :page, :includes, :all, :select, :map
      TERMINAL_METHODS = [:count, :pluck,
                          :first, :second, :third, :fourth, :fifth, :forty_two, :last].freeze
      def_delegators :@query, *TERMINAL_METHODS

      # helper for paging
      def limit(number)
        reflect(@query.limit(number))
      end

      def take(number)
        reflect(@query.limit(number))
      end

      def offset(number)
        reflect(@query.offset(number))
      end

      def skip(number)
        reflect(@query.offset(number))
      end

      # continue queries
      def where(*params)
        reflect(@query.where(*params))
      end

      def order(*params)
        reflect(@query.order(*params))
      end

      private

      def get_point(longitude, latitude)
        Arel::Nodes::NamedFunction.new('ST_GeomFromEWKT', ["SRID=4326;POINT (#{longitude} #{latitude})"])
      end

      def get_box(point1, point2)
        Arel::Nodes::NamedFunction.new('ST_MakeBox2D', [point1, point2])
      end

      def contains(geo1, geo2)
        Arel::Nodes::InfixOperation.new('@', geo1, geo2)
      end

      def in_range(range, date)
        Arel::Nodes::InfixOperation.new('@>', range, date)
      end

      # def to_tsvector(field)
      #   Arel::Nodes::NamedFunction.new('to_tsvector', [field]) # [quoted('german'), field])
      # end

      # def trgm_match(text1, text2)
      #   Arel::Nodes::InfixOperation.new('%', text1, text2)
      # end

      def cast_tstz(date)
        Arel::Nodes::NamedFunction.new(
          'CAST', [
            Arel::Nodes::As.new(
              quoted(date),
              Arel::Nodes::SqlLiteral.new('timestamp with time zone')
            )
          ]
        )
      end

      # chain method for Builder pattern
      def reflect(query)
        self.class.new(@locale, query, @joined_search)
      end
    end
  end
end
