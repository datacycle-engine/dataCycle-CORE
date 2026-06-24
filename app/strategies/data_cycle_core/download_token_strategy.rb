# frozen_string_literal: true

module DataCycleCore
  class DownloadTokenStrategy < BaseStrategy
    def valid?
      valid_strategy? &&
        params[:download_token].present? && Rails.cache.exist?("download_#{params[:download_token]}")
    end

    def store?
      false
    end

    def authenticate!
      user = User.find_by(id: Rails.cache.read("download_#{params[:download_token]}"))
      DataCycleCore::Download.remove_token(key: "download_#{params[:download_token]}")

      return success!(user) if validate(user)

      fail!('invalid download token')
    end
  end
end
