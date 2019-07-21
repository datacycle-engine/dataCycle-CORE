# frozen_string_literal: true

module DataCycleCore
  class Download
    def self.temp_token(user:)
      temp_token = SecureRandom.uuid
      key = "download_#{temp_token}"
      Rails.cache.write(key, user.id, expires_in: 2.hours)
      temp_token
    end

    def self.remove_token(key:)
      Rails.cache.delete(key)
    end
  end
end
