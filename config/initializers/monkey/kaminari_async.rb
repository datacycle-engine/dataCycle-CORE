# frozen_string_literal: true

module DataCycleCore
  module KaminariAsyncExtension
    def total_count(column_name = :all, _options = nil)
      binding.pry
    end
  end
end

Rails.application.reloader.to_prepare do
  Kaminari::ActiveRecordRelationMethods.include(DataCycleCore::KaminariAsyncExtension)
end
