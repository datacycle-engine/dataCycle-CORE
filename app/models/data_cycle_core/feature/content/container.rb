# frozen_string_literal: true

module DataCycleCore
  module Feature
    module Content
      module Container
        extend ActiveSupport::Concern

        def siblings
          (parent ? parent.children : self.class.roots).where.not(id:)
        end

        module ClassMethods
          def self.roots
            where(is_part_of: nil)
          end
        end
      end
    end
  end
end
