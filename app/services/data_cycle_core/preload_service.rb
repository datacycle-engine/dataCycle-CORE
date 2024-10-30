# frozen_string_literal: true

module DataCycleCore
  class PreloadService
    class << self
      def preload(resource, relations, scope = nil)
        ActiveRecord::Associations::Preloader.new(
          records: resource,
          associations: relations,
          scope: scope
        ).tap(&:call)
      end
    end
  end
end
