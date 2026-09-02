# frozen_string_literal: true

module DataCycleCore
  module Utility
    module Compute
      # Computes the denormalized overlay_present flag: whether a content has at least
      # one inline-overlay attribute (*_override / *_add) with a present value.
      module Overlay
        class << self
          # true if at least one overlay attribute holds a present value — inline overlays
          # (*_override / *_add) or the legacy overlay relation. computed_parameters is the
          # { overlay_attribute_name => value } hash the compute framework resolves from the
          # (merged) data hash, so all storage locations (JSONB, linked/embedded,
          # classification) are covered.
          def overlay_present(computed_parameters:, **_args)
            computed_parameters.values.any? { |value| DataCycleCore::DataHashService.present?(value) }
          end
        end
      end
    end
  end
end
