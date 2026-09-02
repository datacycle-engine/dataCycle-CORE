# frozen_string_literal: true

module DataCycleCore
  module KaminariAsyncExtension
    def async_total_count(column_name = :all, options = nil)
      return total_count(column_name, options) if (defined?(@total_count) && @total_count) || loaded?

      c = except(:offset, :limit, :order)
      c = c.except(:includes, :eager_load, :preload) unless references_eager_loaded_tables?
      c = c.limit(max_pages * limit_value) if max_pages.respond_to?(:*)

      @total_count = c.async_count(column_name)
    end

    def total_count(*)
      return @total_count.value if @total_count.is_a?(ActiveRecord::Promise)

      super
    end
  end
end

Rails.application.reloader.to_prepare do
  raise 'Kaminari::ActiveRecordRelationMethods#total_count is no longer available, check patch!' unless Kaminari::ActiveRecordRelationMethods.method_defined?(:total_count, false)

  Kaminari::ActiveRecordRelationMethods.prepend(DataCycleCore::KaminariAsyncExtension)
end
