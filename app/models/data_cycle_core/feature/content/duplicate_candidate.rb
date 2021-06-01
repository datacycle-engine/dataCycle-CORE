# frozen_string_literal: true

module DataCycleCore
  module Feature
    module Content
      module DuplicateCandidate
        include Comparable

        def duplicate_method?
          DataCycleCore::Feature::DuplicateCandidate.duplicate_method(self).present?
        end

        def duplicate_method
          DataCycleCore::Feature::DuplicateCandidate.find_duplicates(self)
        end

        def <=>(other)
          # nativ > imported
          return 1 if external_source_id.blank? && other.external_source_id.present?
          return -1 if other.external_source_id.blank? && external_source_id.present?

          # assets are sorted by size
          if try(:width) && try(:height) && other.try(:width) && other.try(:height)
            return 1 if width * height > other.width * other.height
            return -1 if other.width * other.height > width * height
          end

          # more connections are better
          return 1 if linked_contents.size > other.linked_contents.size
          return -1 if linked_contents.size < other.linked_contents.size
          0 # equivalent
        end

        def original
          return @original if defined? @original

          @original = original_id.present? ? DataCycleCore::Thing.find_by(id: original_id) : nil
        end
      end
    end
  end
end
