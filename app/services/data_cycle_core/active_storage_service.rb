# frozen_string_literal: true

module DataCycleCore
  class ActiveStorageService
    class << self
      def with_current_options(&)
        ActiveStorage::Current.url_options = { host: Rails.application.config.asset_host }

        yield
      end
    end
  end
end
