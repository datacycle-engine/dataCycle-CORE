# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Segments
      class ThingByDataLink < Base
        attr_reader :subject

        def initialize
          @subject = DataCycleCore::Thing
        end

        def include?(content, *_args)
          if DataCycleCore::Feature::Releasable.allowed?(content)
            DataCycleCore::Feature::Releasable.stage_concept_id('partner')&.in?(Array.wrap(content.try(:release_status_id)&.pluck(:id))) &&
              content.valid_writable_links_by_receiver?(user)
          else
            content.valid_writable_links_by_receiver?(user)
          end
        end

        def to_proc
          ->(*args) { include?(*args) }
        end
      end
    end
  end
end
