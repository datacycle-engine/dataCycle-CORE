# frozen_string_literal: true

Rails.application.config.after_initialize do |app|
  key_generator = ActiveSupport::KeyGenerator.new(
    ENV['SECRET_KEY_BASE'].to_s,
    iterations: 1000,
    hash_digest_class: OpenSSL::Digest::SHA1
  )
  secret = key_generator.generate_key('ActiveStorage')
  app.message_verifier('ActiveStorage').rotate(secret)
end
