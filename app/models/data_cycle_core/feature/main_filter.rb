module DataCycleCore
  module Feature
    class MainFilter < Base
      class << self
        def available_filters
          DataCycleCore.features.dig(name.demodulize.underscore.to_sym, :classification_alias_ids) || []
        end
      end
    end
  end
end