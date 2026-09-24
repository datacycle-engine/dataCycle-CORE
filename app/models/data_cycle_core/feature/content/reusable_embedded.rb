# frozen_string_literal: true

module DataCycleCore
  module Feature
    module Content
      # What one embedded answers about the reusable flag and the contents placing it.
      module ReusableEmbedded
        # @return [Boolean] whether the flag is set; nil-safe for templates without the attribute
        def reusable?
          try(DataCycleCore::Feature::ReusableEmbedded.primary_attribute_key) == true
        end

        # Distinct parents: the same content embedding this one under two attributes is one parent,
        # while content_content_b carries a row per attribute.
        #
        # @return [ActiveRecord::Relation<DataCycleCore::Thing>]
        def reusable_parents
          DataCycleCore::Thing.where(id: content_content_b.select(:content_a_id))
        end

        # More than one parent; the flag may have been removed since, so the second parent counts.
        # @return [Boolean]
        def shared_embedded?
          embedded? && reusable_parents.many?
        end
      end
    end
  end
end
