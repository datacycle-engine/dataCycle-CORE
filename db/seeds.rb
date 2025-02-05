# frozen_string_literal: true

DataCycleCore::Role.where(rank: 0).first_or_create({ name: 'guest' })
DataCycleCore::Role.where(rank: 1).first_or_create({ name: 'external_user' })
DataCycleCore::Role.where(rank: 5).first_or_create({ name: 'standard' })
DataCycleCore::Role.where(rank: 10).first_or_create({ name: 'admin' })
DataCycleCore::Role.where(rank: 99).first_or_create({ name: 'super_admin' })

DataCycleCore::Feature::TransitiveClassificationPath.update_triggers(false)

return unless ['test', 'review'].include?(Rails.env)

DataCycleCore::User.where(email: 'admin@datacycle.at').first_or_create({
  given_name: 'Administrator',
  external: false,
  password: 'vy32DHA618dOQk720',
  confirmed_at: 1.day.ago,
  role_id: DataCycleCore::Role.order('rank DESC').first.id
})

DataCycleCore::User.where(email: 'tester@datacycle.at').first_or_create({
  given_name: 'Test',
  family_name: 'User',
  password: 'LiWaL84CNoZ7rSPF',
  confirmed_at: 1.day.ago,
  role_id: DataCycleCore::Role.find_by(name: 'admin')&.id
})
