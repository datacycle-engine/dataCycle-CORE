# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class CreativeWorkTest < ActiveSupport::TestCase
    test 'save proper CreativeWork data-set with hash method' do
      test_hash = { 'name' => 'Dies ist ein Test!', 'description' => 'wtf is going on???' }
      data_set = DataCycleCore::TestPreparations.create_content(template_name: 'Container', data_hash: test_hash)
      assert_equal(test_hash.merge({ 'headline' => data_set.name }), data_set.get_data_hash.compact.except(*DataCycleCore::TestPreparations.excepted_attributes('creative_work')))
    end

    test 'save CreativeWork with only Titel' do
      test_hash = { 'name' => 'Dies ist ein Test!' }
      data_set = DataCycleCore::TestPreparations.create_content(template_name: 'Container', data_hash: test_hash)
      assert_equal(test_hash.merge({ 'headline' => data_set.name }), data_set.get_data_hash.compact.except(*DataCycleCore::TestPreparations.excepted_attributes('creative_work')))
      assert_equal(data_set.cache_key.to_s, "data_cycle_core/things/#{data_set.id}/data_cycle_core/thing/translations/#{data_set.translations.first.id}-de")
      assert_equal(data_set.cache_key_with_version.to_s, "data_cycle_core/things/#{data_set.id}/data_cycle_core/thing/translations/#{data_set.translations.first.id}-de-#{data_set.updated_at.utc.to_s(:usec)}")
    end

    test 'save CreativeWork with sub-properties' do
      test_hash = {
        'name' => 'Dies ist ein Test!',
        'validity_period' => {
          'valid_from' => '2017-05-01'.to_date,
          'valid_until' => '2017-06-01'.to_date
        }
      }
      data_set = DataCycleCore::TestPreparations.create_content(template_name: 'Container', data_hash: test_hash)
      assert_equal(test_hash.merge({ 'headline' => data_set.name }), data_set.get_data_hash.compact.except(*DataCycleCore::TestPreparations.excepted_attributes('creative_work')))
    end

    test 'save CreativeWork with irrelevant sub-properties_tree' do
      test_hash = {
        'name' => 'Dies ist ein Test!',
        'validity_period' => {
          'valid_from' => '2017-05-01'.to_date,
          'valid_until' => '2017-06-01'.to_date
        }
      }
      data_set = DataCycleCore::TestPreparations.create_content(template_name: 'Container', data_hash: test_hash)
      assert_equal(test_hash.merge({ 'headline' => data_set.name }), data_set.get_data_hash.compact.except(*DataCycleCore::TestPreparations.excepted_attributes('creative_work')))
      data_set.set_data_hash(data_hash: { 'name' => 'Dies ist ein Test!', 'validity_period' => { 'valid_from' => '2017-05-01', 'valid_until' => '2017-06-01' }, 'test' => { 'test1' => 1, 'test2' => 2, 'test3' => { 'hallo' => 'World' } } })
      assert_equal(test_hash.merge({ 'headline' => data_set.name }), data_set.get_data_hash.compact.except(*DataCycleCore::TestPreparations.excepted_attributes('creative_work')))
    end

    test 'save CreativeWork, Data properly written to jsonb' do
      test_hash = {
        'name' => 'Dies ist ein Test!',
        'validity_period' => {
          'valid_from' => '2017-05-01'.to_date,
          'valid_until' => '2017-06-01'.to_date
        }
      }
      data_set = DataCycleCore::TestPreparations.create_content(template_name: 'Container', data_hash: test_hash)
      assert_equal(test_hash.merge({ 'headline' => data_set.name }), data_set.get_data_hash.compact.except(*DataCycleCore::TestPreparations.excepted_attributes('creative_work')))
      assert_equal(test_hash.dig('validity_period', 'valid_from'), data_set.validity_period.valid_from)
      assert_equal(test_hash.dig('validity_period', 'valid_until'), data_set.validity_period.valid_until)
    end

    test 'save CreativeWork with sub-properties and invalid data' do
      data_set = DataCycleCore::TestPreparations.create_content(template_name: 'Container', data_hash: { 'name' => 'Dies ist ein Test!', 'validity_period' => { 'valid_from' => '2017-05-01', 'valid_until' => '2017-16-01' } })
      assert_equal(2, data_set.errors.messages.size)
    end

    test 'save CreativeWork link to user_id' do
      DataCycleCore::User.create!(
        given_name: 'Test',
        family_name: 'TEST',
        email: "#{SecureRandom.base64(12)}@pixelpoint.at",
        password: 'password'
      )
      current_user = DataCycleCore::User.first
      test_hash = { 'name' => 'Dies ist ein Test!' }
      data_set = DataCycleCore::TestPreparations.create_content(template_name: 'Container', data_hash: test_hash, user: current_user)
      assert_equal(test_hash.merge({ 'headline' => data_set.name }), data_set.get_data_hash.compact.except(*DataCycleCore::TestPreparations.excepted_attributes('creative_work')))
      assert_equal(current_user.id, data_set.updated_by)
    end
    # TODO: move to specific test
    # test 'save Recherche and read back' do
    #   data_set = DataCycleCore::CreativeWork.new(template_name: 'Recherche')
    #   data_set.save
    #   DataCycleCore::CreativeWork.create!(headline: 'Test')
    #   uuid = DataCycleCore::CreativeWork.where(headline: 'Test').first.id
    #   DataCycleCore::CreativeWork.create!(headline: 'Test2')
    #   uuid2 = DataCycleCore::CreativeWork.where(headline: 'Test2').first.id
    #   data_set.set_data_hash(data_hash: { 'text' => 'Dies ist ein Test!', 'image' => [uuid, uuid2] })
    #   data_set.save
    #   expected_hash = {
    #     'text' => 'Dies ist ein Test!',
    #     'creator' => [],
    #     'image' => [uuid, uuid2]
    #   }
    #   assert_equal(expected_hash.except('image'), data_set.get_data_hash.compact.except('id', 'data_pool', 'video', 'image'))
    #   assert_equal(expected_hash['image'].sort, data_set.get_data_hash['image'].pluck(:id).sort)
    # end
    #
    test 'partially update datahash' do
      image_content = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: { 'name' => 'Test3' })

      test_hash = {
        'name' => 'Dies ist ein Test!',
        'description' => 'wtf is going on???',
        'image' => [image_content.id]
      }
      content = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: test_hash, prevent_history: true)
      assert_equal(test_hash.except('image', 'keywords').merge({ 'headline' => content.name }), content.get_data_hash.compact.except(*DataCycleCore::TestPreparations.excepted_attributes('creative_work')))
      assert_equal(test_hash['image'], content.image.pluck(:id))

      test_hash['description'] = 'only change description'
      content.set_data_hash(data_hash: { 'description' => test_hash['description'] }, partial_update: true, prevent_history: true)
      assert_equal(test_hash.except('image', 'keywords').merge({ 'headline' => content.name }), content.get_data_hash.compact.except(*DataCycleCore::TestPreparations.excepted_attributes('creative_work')))
      assert_equal(test_hash['image'], content.image.pluck(:id))
    end
  end
end
