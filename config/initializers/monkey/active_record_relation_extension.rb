# frozen_string_literal: true

raise 'ActiveRecord::Relation#load is no longer available, check patch!' unless ActiveRecord::Relation.method_defined? :load

module DataCycleCore
  module ActiveRecordRelationExtension
    def load(&)
      return super(&) unless is_a?(DataCycleCore::Thing.const_get(:ActiveRecord_Relation))

      super do |record|
        record.instance_variable_set(:@_current_collection, self)
        yield record if block_given?
      end
    end
  end
end

ActiveRecord::Relation.prepend(DataCycleCore::ActiveRecordRelationExtension)
