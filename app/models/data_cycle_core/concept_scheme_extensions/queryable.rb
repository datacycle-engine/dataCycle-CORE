# frozen_string_literal: true

module DataCycleCore
  module ConceptSchemeExtensions
    # The scopes the API applies to a scheme before it renders it. concept_schemes and
    # concept_scheme_histories hold the same columns, so a since-deleted request narrows and orders
    # the history rows exactly as a live request narrows the scheme table.
    module Queryable
      extend ActiveSupport::Concern

      included do
        scope :visible, ->(context) { where("? = ANY(#{quoted_table_name}.visibility)", context) }
        scope :search, ->(q) { where("#{quoted_table_name}.name ILIKE :q", { q: "%#{q.squish.gsub(/\s/, '%')}%" }) }
        scope :order_by_similarity, ->(term) { order([Arel.sql("similarity(#{quoted_table_name}.name, ?) DESC"), term]) }
      end
    end
  end
end
