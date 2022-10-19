# frozen_string_literal: true

Rails.application.reloader.to_prepare do
  Warden::Strategies.add(:guest_user, DataCycleCore::GuestUserStrategy)
  Warden::Strategies.add(:download_token, DataCycleCore::DownloadTokenStrategy)
  Warden::Strategies.add(:api_bearer_token, DataCycleCore::ApiBearerTokenStrategy)
  Warden::Strategies.add(:api_token, DataCycleCore::ApiTokenStrategy)
  Warden::Strategies.add(:email_password, DataCycleCore::EmailPasswordStrategy)
end
