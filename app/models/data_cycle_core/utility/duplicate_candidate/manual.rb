# frozen_string_literal: true

module DataCycleCore
  module Utility
    module DuplicateCandidate
      # Marker for duplicate pairs a user established explicitly (e.g. via the APIv4 duplicates
      # endpoint) instead of a detection module. It never detects anything itself and is not meant to
      # be configured on a template - it exists so the +manual+ method value resolves to a class with
      # a label: Thing::DuplicateCandidate#duplicate_module looks the method up via
      # ModuleService.load_module, which raises LoadError for unknown identifiers, and
      # DuplicateCandidateHelper#duplicate_score_tag calls that for every candidate it renders.
      #
      # Pairs carrying this method are protected from the automatic cleanup, see
      # Feature::DuplicateCandidate.reserved_methods.
      class Manual < Base
        PARAMETERS = [].freeze

        class << self
          # @return [Array] always empty - manual pairs are persisted, never re-derived
          def duplicates(**)
            []
          end
        end
      end
    end
  end
end
