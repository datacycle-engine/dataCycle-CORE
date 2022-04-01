# frozen_string_literal: true

module DataCycleCore
  class DownloadTokenStrategy < Warden::Strategies::Base
    def valid?
      params[:download_token].present? && Rails.cache.exist?("download_#{params[:download_token]}")
    end

    def store?
      false
    end

    def authenticate!
      user = User.find_by(id: Rails.cache.read("download_#{params[:download_token]}"))
      DataCycleCore::Download.remove_token(key: "download_#{params[:download_token]}")

      user.nil? ? fail!('invalid download token') : success!(user)
    end
  end
end
