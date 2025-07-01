# frozen_string_literal: true

module DataCycleCore
  module Feature
    def self.[](key)
      key = key.to_s.classify

      return Module.const_get("Datacycle::Feature::#{key}::Base") if Module.const_defined?("Datacycle::Feature::#{key}::Base")
      return Module.const_get("DataCycleCore::Feature::#{key}") if Module.const_defined?("DataCycleCore::Feature::#{key}")

      nil # feature (gem) not included
    end
  end
end
