# frozen_string_literal: true

module DataCycleCore
  module Export
    module Generic
      # Everything DataCycleCore::Export::Generic::Update, Create and Delete do: enqueue the
      # delivery, and read their export filter under their own demodulised name — the convention
      # DataCycleCore::ExternalSystem#export_filter_method_name mirrors from the config side.
      module StrategyDefaults
        # @param utility_object [DataCycleCore::Export::PushObject] the receiver and action to send for
        # @param data [DataCycleCore::Thing] the content to send
        # @return [void]
        def process(utility_object:, data:)
          return if data.blank?

          Functions.enqueue(utility_object:, data:)
        end

        # @param data [DataCycleCore::Thing] the content to decide about
        # @param external_system [DataCycleCore::ExternalSystem] the receiver whose filter to read
        # @return [Boolean] whether this content may be sent to it
        def filter(data, external_system)
          Functions.filter(data:, external_system:, method_name: name.demodulize.underscore)
        end
      end
    end
  end
end
