# frozen_string_literal: true

module DataCycleCore
  module Report
    module Downloads
      class WidgetUsage < Base
        def apply(_params)
          raw_query = WidgetUsageBase.base_query(is_overview: false)

          # no need to sanitize the query as it is a constant string
          @data = ActiveRecord::Base.connection.select_all(raw_query)
        end
      end
    end
  end
end
