module DataCycleCore
  module Filter
    class QueryBuilder
      extend Forwardable
      include Enumerable

      attr_reader :query
      def_delegators :@query, :to_a, :to_sql, :each, :page, :includes, :all, :select
      TERMINAL_METHODS = [:count, :pluck,
                          :first, :second, :third, :fourth, :fifth, :forty_two, :last]
      def_delegators :@query, *TERMINAL_METHODS

      def initialize(locale = 'de', query = nil)
        @locale = locale
        @query = query
      end

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

      def group(*params)
        reflect(@query.group(*params))
      end

      def having(*params)
        reflect(@query.having(*params))
      end

      # different filters
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

      def with_classification_aliases(tree_name, *aliases)
        reflect
        @query.where(search[:content_data_id].in(
                       create_classification_alias_recursion(
                         DataCycleCore::ClassificationAlias.for_tree(tree_name).with_name(aliases).pluck(:id)
                       )
        ))
      end

      private

      def create_classification_alias_recursion(ids)
        children = Arel::Table.new(:children)
        recursive_term = Arel::SelectManager.new
          .from(classification_tree)
          .project(Arel.star)
          .where(classification_tree[:parent_classification_alias_id].in(ids))
        non_recursive_term = Arel::SelectManager.new
          .project(classification_tree[Arel.star])
          .from(classification_tree).join(children)
          .on(classification_tree[:parent_classification_alias_id].eq(children[:classification_alias_id]))
        union = recursive_term.union(:all, non_recursive_term)
        cte_as_statement = Arel::Nodes::As.new(children, union)
        select_manager = Arel::SelectManager.new(ActiveRecord::Base).freeze
        manager = select_manager
          .with(:recursive, cte_as_statement)
          .from(children)
          .project(children[:classification_alias_id])

        query2 = join_classification_alias2
        manager2 = query2.where(classification_alias[:id].in(manager)
                                  .or(classification_alias[:id].in(ids)))
      end

      # custom function helper
      def get_point(longitude, latitude)
        Arel::Nodes::NamedFunction.new('ST_GeomFromEWKT', ["SRID=4326;POINT (#{longitude} #{latitude})"])
      end

      def get_box(point1, point2)
        Arel::Nodes::NamedFunction.new('ST_MakeBox2D', [point1, point2])
      end

      def st_distance(point1, point2)
        Arel::Nodes::NamedFunction.new('ST_Distance', [point1, point2])
      end

      def current_date
        Arel::Nodes::NamedFunction.new('CURRENT_DATE', [])
      end

      def contains(geo1, geo2)
        Arel::Nodes::InfixOperation.new('@', geo1, geo2)
      end

      def to_tsvector(field)
        Arel::Nodes::NamedFunction.new('to_tsvector', [field]) # [quoted('german'), field])
      end

      def coalesce(field1, field2)
        Arel::Nodes::NamedFunction.new('coalesce', [field1, field2])
      end

      def to_tsquery(string)
        Arel::Nodes::NamedFunction.new('plainto_tsquery', [quoted('simple'), string]) # [quoted('german'), string])
      end

      def tsmatch(tsvector, tsquery)
        Arel::Nodes::InfixOperation.new('@@', tsvector, tsquery)
      end

      def in_range(range, date)
        Arel::Nodes::InfixOperation.new('@>', range, date)
      end

      def trgm_match(text1, text2)
        Arel::Nodes::InfixOperation.new('%', text1, text2)
      end

      def concatinate(string1, string2)
        Arel::Nodes::InfixOperation.new('||', string1, string2)
      end

      def similar_to(field, string)
        Arel::Nodes::InfixOperation.new('SIMILAR TO', field, quoted(string))
      end

      def quoted(string)
        Arel::Nodes.build_quoted(string)
      end

      def json_element(field, element)
        Arel::Nodes::InfixOperation.new('->>', field, element)
      end

      def json_path(field, path)
        Arel::Nodes::InfixOperation.new('#>>', field, path)
      end

      def sql_date(field)
        Arel::Nodes::NamedFunction.new('date', [field])
      end

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

      # define Arel-tables
      def classification
        Classification.arel_table
      end

      def classification_group
        ClassificationGroup.arel_table
      end

      def classification_alias
        ClassificationAlias.arel_table
      end

      def classification_tree
        ClassificationTree.arel_table
      end

      # chain method for Builder pattern
      def reflect(query)
        self.class.new(@locale, query)
      end
    end
  end
end
