# frozen_string_literal: true

if DataCycleCore::Role.count.zero?
  DataCycleCore::Role.create!(
    rank: 0,
    name: 'guest'
  )
  DataCycleCore::Role.create!(
    rank: 5,
    name: 'standard'
  )
  DataCycleCore::Role.create!(
    rank: 10,
    name: 'admin'
  )
end

if DataCycleCore::User.where(given_name: 'Ad', family_name: 'Ministrator', email: 'admin@datacycle.at').count.zero?
  DataCycleCore::User.create!(
    given_name:   'Ad',
    family_name:  'Ministrator',
    email:        'admin@datacycle.at',
    admin:        true,
    password:     '3amMQf74vp7Zpfdi',
    role_id:      DataCycleCore::Role.find_by(rank: 10)&.id
  )
end

if !Rails.env.production? && DataCycleCore::User.where(given_name: 'Test', family_name: 'User', email: 'tester@datacycle.at').count.zero?
  DataCycleCore::User.create!(
    given_name:   'Test',
    family_name:  'User',
    email:        'tester@datacycle.at',
    admin:        true,
    password:     'w9NGXs2ZLUydJF8r',
    role_id:      DataCycleCore::Role.find_by(rank: 10)&.id
  )
end

if DataCycleCore::Release.count.zero?
  DataCycleCore::Release.create!(
    release_code: 0,
    release_text: 'freigegeben'
  )
  DataCycleCore::Release.create!(
    release_code: 1,
    release_text: 'beim Partner'
  )
  DataCycleCore::Release.create!(
    release_code: 3,
    release_text: 'in Review'
  )
  DataCycleCore::Release.create!(
    release_code: 10,
    release_text: 'archiviert'
  )
end
