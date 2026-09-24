# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Segments
      # The "was this imported?" condition for a rule's subjects. Three models spell it three ways:
      # Concept and ConceptScheme carry external_system_id, Thing and Schedule kept
      # external_source_id, and a ConceptLink carries neither - its provenance is the concept it
      # points at, which is where an import stamps the external system now that the link itself has
      # no column (concept_links is id, parent_id, child_id, link_type).
      #
      # CanCanCan puts one condition hash on a rule, so the subjects of one rule have to agree on the
      # shape; #not_external_conditions raises rather than silently granting when they do not.
      module NotExternalConditions
        EXTERNAL_SYSTEM_MODELS = ['DataCycleCore::Concept', 'DataCycleCore::ConceptScheme'].freeze
        LINK_MODELS = ['DataCycleCore::ConceptLink'].freeze

        private

        def not_external_conditions
          shapes = Array.wrap(subject).map { |s| external_shape(s) }.uniq

          raise ArgumentError, "#{self.class.name}: #{subject.join(', ')} do not share an external-system column" if shapes.many?

          shapes.first || { external_source_id: nil }
        end

        def external_shape(model)
          case model.to_s
          when *EXTERNAL_SYSTEM_MODELS then { external_system_id: nil }
          when *LINK_MODELS then { child: { external_system_id: nil } }
          else { external_source_id: nil }
          end
        end
      end
    end
  end
end
