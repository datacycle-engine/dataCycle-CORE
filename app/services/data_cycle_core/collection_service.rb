# frozen_string_literal: true

module DataCycleCore
  module CollectionService
    class << self
      def to_select_options(collection, locale = DataCycleCore.ui_locales.first)
        collection.to_a.map do |s|
          if s['class_name'] == 'stored_filter'
            DataCycleCore::StoredFilter.instantiate(s).to_select_option(locale)
          elsif s['class_name'] == 'watch_list'
            DataCycleCore::WatchList.instantiate(s).to_select_option(locale)
          end
        end
      end
    end
  end
end
