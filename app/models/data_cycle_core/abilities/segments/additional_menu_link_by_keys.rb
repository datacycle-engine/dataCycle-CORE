# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Segments
      # Permits the sidebar menu links whose configuration key is listed, or every configured link
      # when given `all`. Links declaring their own `:permission:` are checked against that
      # permission instead and never reach this segment.
      class AdditionalMenuLinkByKeys < Base
        attr_reader :subject, :keys

        def initialize(*keys)
          @keys = keys.flatten.map(&:to_s)
          @subject = DataCycleCore::AdditionalMenuLink
        end

        # @param link [DataCycleCore::AdditionalMenuLink] the link CanCan is checking
        # @return [Boolean]
        def include?(link, *_args)
          return false unless link.is_a?(DataCycleCore::AdditionalMenuLink)

          keys.include?('all') || keys.include?(link.key)
        end

        # @return [Proc] the CanCan rule block, applied by PermissionsList.add_abilities_for_user
        def to_proc
          ->(*args) { include?(*args) }
        end

        private

        def to_restrictions(**)
          to_restriction(data: keys.join(', '))
        end
      end
    end
  end
end
