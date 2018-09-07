# frozen_string_literal: true

DataCycleCore::Role.where(rank: 0).first_or_create({
  name: 'guest'
})
DataCycleCore::Role.where(rank: 5).first_or_create({
  name: 'standard'
})
DataCycleCore::Role.where(rank: 10).first_or_create({
  name: 'admin'
})
DataCycleCore::Role.where(rank: 99).first_or_create({
  name: 'super_admin'
})

if DataCycleCore::User.where(given_name: 'Ad', family_name: 'Ministrator', email: 'admin@datacycle.at').count.zero?
  DataCycleCore::User.create!(
    given_name:   'Ad',
    family_name:  'Ministrator',
    email:        'admin@datacycle.at',
    admin:        true,
    password:     '3amMQf74vp7Zpfdi',
    role_id:      DataCycleCore::Role.order('rank DESC').first.id
  )
end

if !Rails.env.production? && DataCycleCore::User.where(given_name: 'Test', family_name: 'User', email: 'tester@datacycle.at').count.zero?
  DataCycleCore::User.create!(
    given_name:   'Test',
    family_name:  'User',
    email:        'tester@datacycle.at',
    admin:        true,
    password:     'w9NGXs2ZLUydJF8r',
    role_id:      DataCycleCore::Role.order('rank DESC').first.id
  )
end
