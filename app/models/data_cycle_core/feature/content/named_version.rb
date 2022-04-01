# frozen_string_literal: true

module DataCycleCore
  module Feature
    module Content
      module NamedVersion
        extend ActiveSupport::Concern

        def named_histories
          histories.where.not(version_name: nil)
        end

        def previous_named_history
          named_histories.first || histories.last
        end
      end
    end
  end
end
