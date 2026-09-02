# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Segments
      # Permits Things that match an inline stored-filter definition, resolved for the
      # current user the same way `DataCycleCore.user_filters` are (supports the `union`
      # shorthand and `current_user` substitution). Use it to keep permissions (e.g.
      # detail-page `:show`) in sync with a forced user filter.
      class ThingsByStoredFilter < Base
        attr_reader :subject

        def initialize(definition)
          @definition = Array.wrap(definition)
          @subject = DataCycleCore::Thing
        end

        # True when +content+ is contained in the stored-filter definition resolved for the current user.
        # Uses the nested (locale-agnostic) query so a permission check never misses content that only
        # exists in another locale.
        def include?(content, *_args)
          return false if @definition.blank?

          filter = DataCycleCore::StoredFilter.new(language: ['all'])
          filter.parameters = resolved_parameters
          filter.things_nested.exists?(id: content.id)
        end

        # Block form of #include? so the segment can back a CanCanCan block rule.
        def to_proc
          ->(*args) { include?(*args) }
        end

        private

        def resolved_parameters
          @definition.map do |definition|
            DataCycleCore::Type::StoredFilter::Parameters.param_from_definition(definition, 'a', user)
          end
        end
      end
    end
  end
end
