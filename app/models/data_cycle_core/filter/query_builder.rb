module DataCycleCore
  module Filter
    class QueryBuilder
      extend Forwardable
      include Enumerable

      attr_reader :query
      def_delegators :@query, :to_a, :to_sql, :each, :order
      TERMINAL_METHODS = [:count, :pluck,
        :first, :second, :third, :fourth, :fifth, :forty_two, :last]
      def_delegators :@query, *TERMINAL_METHODS

      def initialize(uuid, query = nil, translation = false, classification_alias = false)
        @translation = translation
        @classification_alias = classification_alias
        @uuid = uuid
        @query = query
      end


    # helper for paging
      def take(number)
        reflect(
          @query.take(number)
        )
      end

      def limit(number)
        take(number)
      end

      def skip(number)
        reflect(
          @query.skip(number)
        )
      end

      def offset(number)
        skip(number)
      end


      def with_classification_alias(name)
        unless @classification_alias # see if joins are necessary
          @query = join_classification_alias
          @classification_alias = true
        end
        reflect(
          @query.where(
            tsmatch(to_tsvector(classification_alias[:name]), to_tsquery(quoted(name)))
          )
        )
      end

      def with_classification_alias_ids(ids = nil)
        unless @classification_alias # see if joins are necessary
          @query = join_classification_alias
          @classification_alias = true
        end
        result = get_ids_children(ids)
        classification_ids = ids + result.map{|item| item["top_id"]} # parents + children
        reflect(
          @query.where(
            classification_alias[:id].in(classification_ids)
          )
        )
      end

    private

      def get_ids_children(ids)
        # ids = ['0543d553-3c2d-4f49-bf19-5d2e59a15d82', '5ae2c5f2-1534-4800-b1fb-216b789cf9cb']
        ids_string = "('"+ids.join("', '")+"')"
        sql = <<-eos
          WITH RECURSIVE children(top_id) AS
          (
            SELECT classification_alias_id FROM classification_trees
              WHERE parent_classification_alias_id IN #{ids_string}
          UNION ALL
            SELECT t.classification_alias_id from children, classification_trees t
              WHERE t.parent_classification_alias_id = children.top_id
          )
          SELECT * FROM children;
        eos
        result = ActiveRecord::Base.connection.execute(sql)
      end

    # custom function helper
      def get_point(longitude,latitude)
        Arel::Nodes::NamedFunction.new("ST_GeomFromEWKT", ["SRID=4326;POINT (#{longitude} #{latitude})"])
      end

      def get_box(point1, point2)
        Arel::Nodes::NamedFunction.new("ST_MakeBox2D", [point1, point2])
      end

      def st_distance(point1, point2)
        Arel::Nodes::NamedFunction.new("ST_Distance", [point1, point2])
      end

      def contains(geo1, geo2)
        Arel::Nodes::InfixOperation.new("@", geo1, geo2)
      end

      def to_tsvector(field)
        Arel::Nodes::NamedFunction.new("to_tsvector", [field]) #[quoted("german"), field])
      end

      def to_tsquery(string)
        Arel::Nodes::NamedFunction.new("to_tsquery", [string]) #[quoted("german"), string])
      end

      def tsmatch(tsvector, tsquery)
        Arel::Nodes::InfixOperation.new("@@", tsvector, tsquery)
      end

      def quoted(string)
        Arel::Nodes.build_quoted(string)
      end

    # chain method for Builder pattern
      def reflect(query)
        self.class.new(@uuid, query, @translation, @classification_alias)
      end

    # define Arel-tables
      def classification_alias
        ClassificationAlias.arel_table
      end

    end
  end
end
