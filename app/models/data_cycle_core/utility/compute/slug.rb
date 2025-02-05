# frozen_string_literal: true

module DataCycleCore
  module Utility
    module Compute
      module Slug
        extend Extensions::ValueByPathExtension

        class << self
          def slug_value_from_first_existing_linked(computed_parameters:, computed_definition:, content:, key:, **args)
            value = Common.attribute_value_from_first_existing_linked(computed_parameters:, computed_definition:, content:, key:, **args)

            content.slugify(value)
          end
        end
      end
    end
  end
end
