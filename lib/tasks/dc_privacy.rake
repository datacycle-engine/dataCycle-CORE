# frozen_string_literal: true

namespace :dc do
  namespace :privacy do
    desc 'obscure users by replacing given names and family names with random ones'
    task obscure_users: :environment do
      Faker::Config.locale = 'de_AT'

      DataCycleCore::User.all.each do |user|
        user.given_name = Faker::Name.first_name
        user.family_name = Faker::Name.last_name
        user.email = "#{user.given_name}.#{user.family_name}@example.com".downcase
        user.save!
      end
    end

    desc 'lock users after not consenting for specified duration'
    task lock_users_without_consent: :environment do
      next unless DataCycleCore::Feature::UserRegistration.enabled?

      users = DataCycleCore::Feature::UserRegistration.users_outside_grace_period

      puts "LOCK USERS OUTSIDE GRACE PERIOD (#{users.size})"

      users.find_each(&:lock_access!)
    end
  end
end
