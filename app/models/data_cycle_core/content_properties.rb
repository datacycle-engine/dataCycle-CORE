# frozen_string_literal: true

module DataCycleCore
  # Backed by the content_properties materialized view, which has no id column. Both columns together identify a row.
  class ContentProperties < ApplicationRecord
    self.implicit_order_column = [:template_name, :property_name]

    belongs_to :thing_template, inverse_of: false, foreign_key: :template_name, primary_key: :template_name

    def readonly?
      true
    end
  end
end
