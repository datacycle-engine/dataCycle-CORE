# frozen_string_literal: true

module DataCycleCore
  module Feature
    module Content
      module Container
        extend ActiveSupport::Concern

        def siblings
          # Query the STI root (DataCycleCore::Thing), not self.class: self.class is the
          # per-template STI subclass and would restrict siblings to the parent's template_name.
          # The parent.children branch already spans templates (its class_name is DataCycleCore::Thing).
          (parent ? parent.children : DataCycleCore::Thing.roots).where.not(id:)
        end

        module ClassMethods
          # `def roots`, not `def self.roots`: ActiveSupport::Concern extends this module onto the
          # including class, promoting its INSTANCE methods to class methods. `def self.roots` would
          # attach to the ClassMethods module object instead, leaving Thing.roots undefined.
          def roots
            where(is_part_of: nil)
          end
        end
      end
    end
  end
end
