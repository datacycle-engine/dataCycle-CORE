# frozen_string_literal: true

module DataCycleCore
  module Utility
    module Virtual
      module Creator
        class << self
          def object(content:, **_args)
            content&.created_by_user&.as_json(only: [:email, :given_name, :family_name])&.deep_transform_keys { |k| k.camelize(:lower) }
          end
        end
      end
    end
  end
end
