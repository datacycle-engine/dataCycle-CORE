# frozen-string-literal: true

module DataCycleCore
  module Translation
    module Arel
      module Nodes
        class Binary < ::Arel::Nodes::Binary; end
        class Grouping < ::Arel::Nodes::Grouping; end

        ::Arel::Visitors::ToSql.class_eval do
          alias_method :visit_Translation_Arel_Nodes_Grouping, :visit_Arel_Nodes_Grouping
        end
      end
    end
  end
end
