# frozen_string_literal: true

DataCycleCore::Role.where(rank: 0).first_or_create({ name: 'guest' })
DataCycleCore::Role.where(rank: 5).first_or_create({ name: 'standard' })
DataCycleCore::Role.where(rank: 10).first_or_create({ name: 'admin' })
DataCycleCore::Role.where(rank: 99).first_or_create({ name: 'super_admin' })

DataCycleCore::User.where(email: 'admin@datacycle.at').first_or_create({
  given_name: 'Administrator',
  external: false,
  password: '6p8GlvYjM5TtpuLc',
  confirmed_at: Time.zone.now - 1.day,
  role_id: DataCycleCore::Role.order('rank DESC').first.id
})

return unless ['test', 'review'].include?(Rails.env)

DataCycleCore::User.where(email: 'tester@datacycle.at').first_or_create({
  given_name: 'Test',
  family_name: 'User',
  password: 'LiWaL84CNoZ7rSPF',
  confirmed_at: Time.zone.now - 1.day,
  role_id: DataCycleCore::Role.find_by(name: 'admin')&.id
})
