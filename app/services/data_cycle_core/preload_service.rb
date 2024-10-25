# frozen_string_literal: true

module DataCycleCore
  class PreloadService
    class << self
      def preload(resource, relations, scope = nil)
        ActiveRecord::Associations::Preloader.new.preload(
          resource,
          relations,
          scope
        )
      end
    end
  end
end
