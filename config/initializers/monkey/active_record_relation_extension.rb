# frozen_string_literal: true

raise 'ActiveRecord::Relation#load is no longer available, check patch!' unless ActiveRecord::Relation.method_defined? :load

module DataCycleCore
  module ActiveRecordRelationExtension
    # used for property_preloader
    # def load(&)
    #   return super unless is_a?(Thing.const_get(:ActiveRecord_Relation))

    #   super do |record|
    #     record.instance_variable_set(:@_current_collection, self)
    #     yield record if block_given?
    #   end
    # end

    def async_total_count(column_name = :all)
      return total_count(column_name) if (defined?(@total_count) && @total_count) || loaded?

      c = except(:offset, :limit, :order)
      c = c.except(:includes, :eager_load, :preload) unless references_eager_loaded_tables?

      @total_count = c.async_count(column_name)
    end

    def total_count(column_name = :all)
      return @total_count.value if @total_count.is_a?(ActiveRecord::Promise)

      count(column_name)
    end
  end
end

ActiveRecord::Relation.prepend(DataCycleCore::ActiveRecordRelationExtension)
