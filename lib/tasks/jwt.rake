# frozen_string_literal: true

namespace :jwt do
  desc 'generate a new private/public key pair for signing JWTs'
  task generate_key_pair: :environment do
    pkey = OpenSSL::PKey::RSA.generate 2048

    puts '################################################################'
    puts '########################## PRIVATE KEY #########################'
    puts '################################################################'
    puts pkey.to_pem

    puts '################################################################'
    puts '########################## PUBLIC KEY ##########################'
    puts '################################################################'
    puts pkey.public_key.to_pem
  end
end
