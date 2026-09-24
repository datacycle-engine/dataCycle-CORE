# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Segments
      # The subject is DataCycleCore::Concept; the class name outlived the model because it is the
      # value host projects write in their own role definitions - data-cycle-oewein, -thermostar,
      # -vtg and oew-content-db each carry
      # `permit_user(role, :destroy, :ClassificationAliasAndChildrenNotExternalAndNotInternal)` in
      # app/extensions/permissions/roles/admin.rb. PermissionsList#segment resolves that symbol
      # through Segments.const_get, so a rename raises NameError while the permission list is
      # built, and no upgrade step reaches those lines: dc:upgrade rewrites config/**/*.yml and
      # leaves hand-written ruby alone.
      class ClassificationAliasAndChildrenNotExternalAndNotInternal < Base
        attr_reader :subject

        def initialize
          @subject = DataCycleCore::Concept
        end

        def include?(concept, *_args)
          concept.external_system_id.nil? && !concept.internal && concept.children&.none?(&:internal) && concept.children.none?(&:external_system_id)
        end

        def to_proc
          ->(*args) { include?(*args) }
        end
      end
    end
  end
end
