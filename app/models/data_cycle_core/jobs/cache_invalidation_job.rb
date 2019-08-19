# frozen_string_literal: true

module DataCycleCore
  module Jobs
    class CacheInvalidationJob < Struct.new(:class_name, :id, :method)
      def perform
        class_name.classify.constantize.find_by(id: id)&.send(method)
      end
    end
  end
end
