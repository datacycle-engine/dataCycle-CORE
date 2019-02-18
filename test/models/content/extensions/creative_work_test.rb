# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class CreativeWorkTest < ActiveSupport::TestCase
    # TODO: move to embedded test (creative work with embedded from other table does not exists anymore)
    # test 'embedded objects are deleted if parent is deleted' do
    #   template_cw = DataCycleCore::CreativeWork.count
    #   template_cwt = DataCycleCore::CreativeWork::Translation.count
    #   template_p = DataCycleCore::Place.count
    #   template_pt = DataCycleCore::Place::Translation.count
    #
    #   template_without_delete = DataCycleCore::CreativeWork.find_by(template: true, template_name: 'Artikel')
    #   data_set_without = DataCycleCore::CreativeWork.new
    #   data_set_without.schema = template_without_delete.schema
    #   data_set_without.template_name = template_without_delete.template_name
    #   data_set_without.save
    #
    #   data_hash = {
    #     'headline' => 'Dies ist ein Test!',
    #     'description' => 'wtf is going on???',
    #     'content_location' => [{
    #       'headline' => 'Testort',
    #       'longitude' => 13.10,
    #       'latitude' => 25.30
    #     }]
    #   }
    #   error = data_set_without.set_data_hash(data_hash: data_hash)
    #   data_set_without.save
    #
    #   returned_data_hash_without = data_set_without.get_data_hash
    #   expected_hash = {
    #     'access' => [],
    #     'creator' => [],
    #     'headline' => 'Dies ist ein Test!',
    #     'description' => 'wtf is going on???',
    #     'content_location' => [{
    #       'id' => returned_data_hash_without['content_location'][0]['id'],
    #       'headline' => 'Testort',
    #       'latitude' => 25.3,
    #       'location' => nil,
    #       'longitude' => 13.1,
    #       'external_source_id' => nil
    #     }]
    #   }
    #
    #   assert_equal(expected_hash, returned_data_hash_without.compact.except('id', 'data_type', 'data_pool', 'keywords'))
    #   assert_equal(0, error[:error].count)
    #
    #   # check consistency of data in DB
    #   assert_equal(1, DataCycleCore::CreativeWork.count - template_cw)
    #   assert_equal(1, DataCycleCore::CreativeWork::Translation.count - template_cwt)
    #   assert_equal(1, DataCycleCore::ContentContent.count)
    #   assert_equal(2, DataCycleCore::ClassificationContent.count)
    #   assert_equal(1, DataCycleCore::Place.count - template_p)
    #   assert_equal(1, DataCycleCore::Place::Translation.count - template_pt)
    #
    #   assert_equal(1, DataCycleCore::CreativeWork::History.count)
    #   assert_equal(1, DataCycleCore::CreativeWork::History::Translation.count)
    #   assert_equal(0, DataCycleCore::ClassificationContent::History.count)
    #   assert_equal(0, DataCycleCore::ContentContent::History.count)
    #   assert_equal(0, DataCycleCore::Place::History.count)
    #   assert_equal(0, DataCycleCore::Place::History::Translation.count)
    #
    #   returned_data_hash_without['content_location'] = []
    #   data_set_without.set_data_hash(data_hash: returned_data_hash_without)
    #   data_set_without.save
    #
    #   returned_again = data_set_without.get_data_hash
    #   assert_equal(returned_data_hash_without, returned_again)
    #
    #   # check consistency of data in DB
    #   assert_equal(1, DataCycleCore::CreativeWork.count - template_cw)
    #   assert_equal(1, DataCycleCore::CreativeWork::Translation.count - template_cwt)
    #   assert_equal(0, DataCycleCore::ContentContent.count)
    #   assert_equal(2, DataCycleCore::ClassificationContent.count)
    #   assert_equal(0, DataCycleCore::Place.count - template_p)
    #   assert_equal(0, DataCycleCore::Place::Translation.count - template_pt)
    #
    #   assert_equal(2, DataCycleCore::CreativeWork::History.count)
    #   assert_equal(2, DataCycleCore::CreativeWork::History::Translation.count)
    #   assert_equal(1, DataCycleCore::ContentContent::History.count)
    #   assert_equal(2, DataCycleCore::ClassificationContent::History.count)
    #   assert_equal(1, DataCycleCore::Place::History.count)
    #   assert_equal(1, DataCycleCore::Place::History::Translation.count)
    # end

    # TODO: move to embedded test (creative work with embedded from other table does not exists anymore)
    # test 'save CreativeWork with embedded object contentLocation, then delete embedded object (last and only one)' do
    #   template = DataCycleCore::CreativeWork.where(template: true, template_name: 'BildTest').first
    #   data_set = DataCycleCore::CreativeWork.new
    #   data_set.schema = template.schema
    #   data_set.template_name = template.template_name
    #   data_set.save
    #   data_hash = {
    #     'headline' => 'Dies ist ein Test!',
    #     'description' => 'wtf is going on???',
    #     'content_location' => [{
    #       'headline' => 'Testort',
    #       'longitude' => 13.10,
    #       'latitude' => 25.30
    #     }]
    #   }
    #   error = data_set.set_data_hash(data_hash: data_hash)
    #   data_set.save
    #   returned_data_hash = data_set.get_data_hash
    #
    #   expected_hash = {
    #     'access' => [],
    #     'headline' => 'Dies ist ein Test!',
    #     'description' => 'wtf is going on???',
    #     'content_location' => [{
    #       'id' => returned_data_hash['content_location'][0]['id'],
    #       'headline' => 'Testort',
    #       'latitude' => 25.3,
    #       'location' => nil,
    #       'longitude' => 13.1,
    #       'external_source_id' => nil
    #     }],
    #     'accountablePerson' => []
    #   }
    #
    #   assert_equal(expected_hash, returned_data_hash.compact.except('id', 'data_type'))
    #   assert_equal(0, error[:error].count)
    #
    #   # check consistency of data in DB
    #   assert_equal(1, DataCycleCore::CreativeWork.where(template: false).count)
    #   assert_equal(1, DataCycleCore::ContentContent.count)
    #   assert_equal(1, DataCycleCore::Place.where(template: false).count)
    #
    #   returned_data_hash['content_location'] = []
    #   data_set.set_data_hash(data_hash: returned_data_hash)
    #   data_set.save
    #   returned_again = data_set.get_data_hash
    #   assert_equal(returned_data_hash, returned_again)
    #
    #   # check consistency of data in DB
    #   assert_equal(1, DataCycleCore::CreativeWork.where(template: false).count)
    #   assert_equal(0, DataCycleCore::ContentContent.count)
    #   assert_equal(0, DataCycleCore::Place.where(template: false).count)
    # end
    #
    # test 'save CreativeWork with embedded object contentLocation, read data with only id given' do
    #   template = DataCycleCore::CreativeWork.where(template: true, template_name: 'Bild').first
    #   data_set = DataCycleCore::CreativeWork.new
    #   data_set.schema = template.schema
    #   data_set.template_name = template.template_name
    #   data_set.save
    #   data_hash = {
    #     'headline' => 'Dies ist ein Test!',
    #     'description' => 'wtf is going on???',
    #     'content_location' => [{
    #       'headline' => 'Testort',
    #       'longitude' => 13.10,
    #       'latitude' => 25.30
    #     }]
    #   }
    #   error = data_set.set_data_hash(data_hash: data_hash)
    #   data_set.save
    #   returned_data_hash = data_set.get_data_hash
    #
    #   expected_hash = {
    #     'access' => [],
    #     'creator' => [],
    #     'headline' => 'Dies ist ein Test!',
    #     'description' => 'wtf is going on???',
    #     'content_location' => [{
    #       'id' => returned_data_hash['content_location'][0]['id'],
    #       'headline' => 'Testort',
    #       'latitude' => 25.3,
    #       'location' => nil,
    #       'longitude' => 13.1,
    #       'external_source_id' => nil
    #     }]
    #   }
    #
    #   assert_equal(expected_hash, returned_data_hash.compact.except('id', 'data_type', 'keywords', 'data_pool'))
    #   assert_equal(0, error[:error].count)
    #
    #   # check consistency of data in DB
    #   assert_equal(1, DataCycleCore::CreativeWork.where(template: false).count)
    #   assert_equal(1, DataCycleCore::ContentContent.count)
    #   assert_equal(1, DataCycleCore::Place.where(template: false).count)
    #
    #   returned_data_hash['content_location'] = [{ 'id' => returned_data_hash['content_location'][0]['id'] }]
    #   data_set.set_data_hash(data_hash: returned_data_hash)
    #   data_set.save
    #   returned_again = data_set.get_data_hash
    #   assert_equal(expected_hash, returned_again.compact.except('id', 'data_type', 'keywords', 'data_pool'))
    #
    #   # check consistency of data in DB
    #   assert_equal(1, DataCycleCore::CreativeWork.where(template: false).count)
    #   assert_equal(1, DataCycleCore::ContentContent.count)
    #   assert_equal(1, DataCycleCore::Place.where(template: false).count)
    # end

    # TODO: move to embedded test (creative work with embedded from other table does not exists anymore)
    # test 'save CreativeWork with embedded object contentLocation, create relation with only id given' do
    #   # insert a place
    #   template = DataCycleCore::Place.find_by(template: true, template_name: 'contentLocation')
    #   data_set_place = DataCycleCore::Place.new
    #   data_set_place.schema = template.schema
    #   data_set_place.template_name = template.template_name
    #   data_set_place.save
    #   place_hash = {
    #     'name' => 'Testort',
    #     'longitude' => 13.10,
    #     'latitude' => 25.30
    #   }
    #   data_set_place.set_data_hash(data_hash: place_hash)
    #   data_set_place.save
    #   returned_place = data_set_place.get_data_hash
    #   place_id = returned_place['id']
    #
    #   # insert an image and connect it to an existing place
    #   template = DataCycleCore::CreativeWork.find_by(template: true, template_name: 'Bild')
    #   data_set = DataCycleCore::CreativeWork.new
    #   data_set.schema = template.schema
    #   data_set.template_name = template.template_name
    #   data_set.save
    #   data_hash = {
    #     'headline' => 'Dies ist ein Test!',
    #     'description' => 'wtf is going on???',
    #     'content_location' => [{ 'id' => place_id }]
    #   }
    #   error = data_set.set_data_hash(data_hash: data_hash)
    #   data_set.save
    #
    #   returned_data_hash = data_set.get_data_hash
    #
    #   expected_hash = {
    #     'access' => [],
    #     'creator' => [],
    #     'headline' => 'Dies ist ein Test!',
    #     'description' => 'wtf is going on???',
    #     'content_location' => [returned_place]
    #   }
    #
    #   assert_equal(expected_hash, returned_data_hash.compact.except('id', 'data_type', 'keywords', 'data_pool'))
    #   assert_equal(0, error[:error].count)
    #
    #   # check consistency of data in DB
    #   assert_equal(1, DataCycleCore::CreativeWork.where(template: false).count)
    #   assert_equal(1, DataCycleCore::ContentContent.count)
    #   assert_equal(1, DataCycleCore::Place.where(template: false).count)
    # end

    # TODO: move to embedded test (creative work with embedded from other table does not exists anymore)
    # test 'save CreativeWork without embedded object contentLocation, update CW and create relation with only id given' do
    #   # insert a place
    #   template = DataCycleCore::Place.find_by(template: true, template_name: 'contentLocation')
    #   data_set_place = DataCycleCore::Place.new
    #   data_set_place.schema = template.schema
    #   data_set_place.template_name = template.template_name
    #   data_set_place.save
    #   place_hash = {
    #     'name' => 'Testort',
    #     'longitude' => 13.10,
    #     'latitude' => 25.30
    #   }
    #   data_set_place.set_data_hash(data_hash: place_hash)
    #   data_set_place.save
    #   returned_place = data_set_place.get_data_hash
    #   place_id = returned_place['id']
    #
    #   # insert an image without connection to a place
    #   template = DataCycleCore::CreativeWork.find_by(template: true, template_name: 'Bild')
    #   data_set = DataCycleCore::CreativeWork.new
    #   data_set.schema = template.schema
    #   data_set.template_name = template.template_name
    #   data_set.save
    #   data_hash = {
    #     'headline' => 'Dies ist ein Test!',
    #     'description' => 'wtf is going on???',
    #     'content_location' => []
    #   }
    #   error = data_set.set_data_hash(data_hash: data_hash)
    #   data_set.save
    #
    #   returned_data_hash = data_set.get_data_hash
    #
    #   expected_hash = {
    #     'access' => [],
    #     'creator' => [],
    #     'headline' => 'Dies ist ein Test!',
    #     'data_type' => returned_data_hash['data_type'],
    #     'data_pool' => returned_data_hash['data_pool'],
    #     'description' => 'wtf is going on???',
    #     'content_location' => []
    #   }
    #
    #   assert_equal(expected_hash, returned_data_hash.compact.except('id', 'keywords'))
    #   assert_equal(0, error[:error].count)
    #
    #   # check consistency of data in DB
    #   assert_equal(1, DataCycleCore::CreativeWork.where(template: false).count)
    #   assert_equal(0, DataCycleCore::ContentContent.count)
    #   assert_equal(1, DataCycleCore::Place.where(template: false).count)
    #   assert_equal(2, DataCycleCore::ClassificationContent.count)
    #
    #   # make relation
    #   data_hash['content_location'] = [{ 'id' => place_id }]
    #   error = data_set.set_data_hash(data_hash: data_hash)
    #   data_set.save
    #   returned_data_hash = data_set.get_data_hash
    #   expected_hash['content_location'] = [returned_place]
    #
    #   assert_equal(expected_hash, returned_data_hash.compact.except('id', 'keywords'))
    #   assert_equal(0, error[:error].count)
    #
    #   # check consistency of data in DB
    #   assert_equal(1, DataCycleCore::CreativeWork.where(template: false).count)
    #   assert_equal(1, DataCycleCore::ContentContent.count)
    #   assert_equal(1, DataCycleCore::Place.where(template: false).count)
    # end
    #
    # TODO: move to embedded test (creative work with embedded from other table does not exists anymore)
    # test 'save CreativeWork with more than one embedded object contentLocation, delete multiple contentLocations at once' do
    #   template = DataCycleCore::CreativeWork.where(template: true, template_name: 'BildTest').first
    #   data_set = DataCycleCore::CreativeWork.new
    #   data_set.schema = template.schema
    #   data_set.template_name = template.template_name
    #   data_set.save
    #   data_hash = {
    #     'headline' => 'Dies ist ein Test!',
    #     'description' => 'wtf is going on???',
    #     'content_location' => [{
    #       'headline' => 'Testort',
    #       'longitude' => 13.1,
    #       'latitude' => 25.3
    #     }, {
    #       'headline' => '2Testort',
    #       'latitude' => 25.3,
    #       'longitude' => 23.1
    #     }, {
    #       'headline' => '3Testort',
    #       'latitude' => 35.3,
    #       'longitude' => 33.1
    #     }]
    #   }
    #   data_set.set_data_hash(data_hash: data_hash)
    #   data_set.save
    #
    #   expected_hash = {
    #     'access' => [],
    #     'headline' => 'Dies ist ein Test!',
    #     'description' => 'wtf is going on???',
    #     'content_location' => [{
    #       'id' => nil,
    #       'headline' => 'Testort',
    #       'latitude' => 25.3,
    #       'location' => nil,
    #       'longitude' => 13.1,
    #       'external_source_id' => nil
    #     }, {
    #       'id' => nil,
    #       'headline' => '2Testort',
    #       'latitude' => 25.3,
    #       'location' => nil,
    #       'longitude' => 23.1,
    #       'external_source_id' => nil
    #     }, {
    #       'id' => nil,
    #       'headline' => '3Testort',
    #       'latitude' => 35.3,
    #       'location' => nil,
    #       'longitude' => 33.1,
    #       'external_source_id' => nil
    #     }],
    #     'accountablePerson' => []
    #   }
    #
    #   returned_data_hash = data_set.get_data_hash.compact
    #   assert_equal(expected_hash.except('content_location'), returned_data_hash.except('content_location', 'data_type'))
    #   assert_equal(expected_hash['content_location'].count, returned_data_hash['content_location'].count)
    #
    #   # check consistency of data in DB
    #   assert_equal(1, DataCycleCore::CreativeWork.where(template: false).count)
    #   assert_equal(3, DataCycleCore::ContentContent.count)
    #   assert_equal(3, DataCycleCore::Place.where(template: false).count)
    #
    #   # delete all places at once
    #   returned_data_hash['content_location'] = []
    #   data_set.set_data_hash(data_hash: returned_data_hash)
    #   data_set.save
    #
    #   data_set.get_data_hash.compact
    #   expected_hash['content_location'] = []
    #   assert_equal(expected_hash, returned_data_hash.except('data_type'))
    #
    #   # check consistency of data in DB
    #   assert_equal(1, DataCycleCore::CreativeWork.where(template: false).count)
    #   assert_equal(0, DataCycleCore::ContentContent.count)
    #   assert_equal(0, DataCycleCore::Place.where(template: false).count)
    # end

    # test 'save CreativeWork with embedded object contentLocation, write, read and write back' do
    #   template = DataCycleCore::CreativeWork.where(template: true, template_name: 'Bild').first
    #   data_set = DataCycleCore::CreativeWork.new
    #   data_set.schema = template.schema
    #   data_set.template_name = template.template_name
    #   data_set.save
    #   data_hash = {
    #     'headline' => 'Dies ist ein Test!',
    #     'description' => 'wtf is going on???',
    #     'content_location' => [{
    #       'headline' => 'Testort',
    #       'longitude' => 13.10,
    #       'latitude' => 25.30
    #     }]
    #   }
    #   error = data_set.set_data_hash(data_hash: data_hash)
    #   data_set.save
    #
    #   returned_data_hash = data_set.get_data_hash
    #
    #   expected_hash = {
    #     'access' => [],
    #     'creator' => [],
    #     'headline' => 'Dies ist ein Test!',
    #     'description' => 'wtf is going on???',
    #     'content_location' => [{
    #       'id' => returned_data_hash['content_location'][0]['id'],
    #       'headline' => 'Testort',
    #       'latitude' => 25.3,
    #       'location' => nil,
    #       'longitude' => 13.1,
    #       'external_source_id' => nil
    #     }]
    #   }
    #
    #   assert_equal(expected_hash, returned_data_hash.except('id', 'data_type', 'keywords', 'data_pool').compact)
    #   assert_equal(0, error[:error].count)
    #
    #   data_set.set_data_hash(data_hash: returned_data_hash)
    #   data_set.save
    #
    #   returned_again = data_set.get_data_hash
    #   assert_equal(returned_data_hash, returned_again)
    #
    #   # check consistency of data in DB
    #   assert_equal(1, DataCycleCore::Place.where(template: false).count)
    #   assert_equal(1, DataCycleCore::CreativeWork.where(template: false).count)
    #   assert_equal(1, DataCycleCore::ContentContent.count)
    # end
    #
    # test 'save CreativeWork with embedded object contentLocation' do
    #   template = DataCycleCore::CreativeWork.where(template: true, template_name: 'Bild').first
    #   data_set = DataCycleCore::CreativeWork.new
    #   data_set.schema = template.schema
    #   data_set.template_name = template.template_name
    #   data_set.save
    #   data_hash = {
    #     'headline' => 'Dies ist ein Test!',
    #     'description' => 'wtf is going on???',
    #     'content_location' => [{
    #       'headline' => 'Testort',
    #       'longitude' => 13.10,
    #       'latitude' => 25.30
    #     }]
    #   }
    #   error = data_set.set_data_hash(data_hash: data_hash)
    #   expected_hash = {
    #     'access' => [],
    #     'creator' => [],
    #     'headline' => 'Dies ist ein Test!',
    #     'description' => 'wtf is going on???',
    #     'content_location' => [{
    #       'id' => nil,
    #       'headline' => 'Testort',
    #       'latitude' => 25.3,
    #       'location' => nil,
    #       'longitude' => 13.1,
    #       'external_source_id' => nil
    #     }]
    #   }
    #   data_set.save
    #   returned_data_hash = data_set.get_data_hash.compact
    #   expected_hash['content_location'][0]['id'] = returned_data_hash['content_location'][0]['id']
    #   assert_equal(expected_hash, returned_data_hash.except('id', 'data_type', 'keywords', 'data_pool'))
    #   assert_equal(0, error[:error].count)
    #
    #   # check consistency of data in DB
    #   assert_equal(1, DataCycleCore::Place.where(template: false).count)
    #   assert_equal(1, DataCycleCore::CreativeWork.where(template: false).count)
    #   assert_equal(1, DataCycleCore::ContentContent.count)
    # end
    #
    # test 'save CreativeWork with embedded object contentLocation consistency check get(set)=set' do
    #   template = DataCycleCore::CreativeWork.where(template: true, template_name: 'BildTest').first
    #   data_set = DataCycleCore::CreativeWork.new
    #   data_set.schema = template.schema
    #   data_set.template_name = template.template_name
    #   data_set.save
    #   data_hash = {
    #     'headline' => 'Dies ist ein Test!',
    #     'description' => 'wtf is going on???',
    #     'content_location' => [{
    #       'headline' => 'Testort',
    #       'longitude' => 13.10,
    #       'latitude' => 25.30
    #     }]
    #   }
    #   data_set.set_data_hash(data_hash: data_hash)
    #   data_set.save
    #   error = data_set.set_data_hash(data_hash: data_set.get_data_hash.compact)
    #   data_set.save
    #   expected_hash = {
    #     'access' => [],
    #     'headline' => 'Dies ist ein Test!',
    #     'description' => 'wtf is going on???',
    #     'content_location' => [{
    #       'id' => nil,
    #       'headline' => 'Testort',
    #       'latitude' => 25.3,
    #       'location' => nil,
    #       'longitude' => 13.1,
    #       'external_source_id' => nil
    #     }],
    #     'accountablePerson' => []
    #   }
    #   data_set.save
    #   returned_data_hash = data_set.get_data_hash.compact
    #   expected_hash['content_location'][0]['id'] = returned_data_hash['content_location'][0]['id']
    #   assert_equal(expected_hash, returned_data_hash.except('id', 'data_type'))
    #   assert_equal(0, error[:error].count)
    #
    #   # check consistency of data in DB
    #   assert_equal(1, DataCycleCore::Place.where(template: false).count)
    #   assert_equal(1, DataCycleCore::CreativeWork.where(template: false).count)
    #   assert_equal(1, DataCycleCore::ContentContent.count)
    # end
    #
    # test 'save CreativeWork with more than one embedded object contentLocation' do
    #   template = DataCycleCore::CreativeWork.where(template: true, template_name: 'Bild').first
    #   data_set = DataCycleCore::CreativeWork.new
    #   data_set.schema = template.schema
    #   data_set.template_name = template.template_name
    #   data_set.save
    #   data_hash = {
    #     'headline' => 'Dies ist ein Test!',
    #     'description' => 'wtf is going on???',
    #     'content_location' => [{
    #       'name' => 'Testort',
    #       'longitude' => 13.1,
    #       'latitude' => 25.3
    #     }, {
    #       'name' => '2Testort',
    #       'latitude' => 25.3,
    #       'longitude' => 23.1
    #     }]
    #   }
    #   data_set.set_data_hash(data_hash: data_hash)
    #   expected_hash = {
    #     'access' => [],
    #     'creator' => [],
    #     'headline' => 'Dies ist ein Test!',
    #     'description' => 'wtf is going on???',
    #     'content_location' => [{
    #       'id' => nil,
    #       'name' => 'Testort',
    #       'latitude' => 25.3,
    #       'location' => nil,
    #       'longitude' => 13.1,
    #       'external_source_id' => nil
    #     }, {
    #       'id' => nil,
    #       'name' => '2Testort',
    #       'latitude' => 25.3,
    #       'location' => nil,
    #       'longitude' => 23.1,
    #       'external_source_id' => nil
    #     }]
    #   }
    #   data_set.save
    #   returned_data_hash = data_set.get_data_hash.compact
    #   returned_data_hash['content_location'][0]['id'] = nil
    #   returned_data_hash['content_location'][1]['id'] = nil
    #   assert_equal(expected_hash.except('content_location'), returned_data_hash.except('content_location', 'id', 'data_type', 'keywords', 'data_pool'))
    #   assert_equal(expected_hash['content_location'].count, returned_data_hash['content_location'].count)
    #
    #   # check consistency of data in DB
    #   assert_equal(2, DataCycleCore::Place.where(template: false).count)
    #   assert_equal(1, DataCycleCore::CreativeWork.where(template: false).count)
    #   assert_equal(2, DataCycleCore::ContentContent.count)
    # end
    #
    # test 'save CreativeWork with two embedded objects then delete one' do
    #   template = DataCycleCore::CreativeWork.where(template: true, template_name: 'BildTest').first
    #   data_set = DataCycleCore::CreativeWork.new
    #   data_set.schema = template.schema
    #   data_set.template_name = template.template_name
    #   data_set.save
    #   data_hash = {
    #     'headline' => 'Dies ist ein Test!',
    #     'description' => 'wtf is going on???',
    #     'content_location' => [{
    #       'headline' => 'Testort',
    #       'longitude' => 13.1,
    #       'latitude' => 25.3
    #     }, {
    #       'headline' => '2Testort',
    #       'latitude' => 25.3,
    #       'longitude' => 23.1
    #     }]
    #   }
    #   data_set.set_data_hash(data_hash: data_hash)
    #   data_set.save
    #   returned_data_hash = data_set.get_data_hash
    #   data_hash2 = returned_data_hash.compact
    #   data_hash2['content_location'] = []
    #   data_hash2['content_location'].push(returned_data_hash['content_location'][1])
    #   data_set.set_data_hash(data_hash: data_hash2.compact)
    #   data_set.save
    #
    #   expected_hash = {
    #     'access' => [],
    #     'headline' => 'Dies ist ein Test!',
    #     'description' => 'wtf is going on???',
    #     'content_location' => [],
    #     'accountablePerson' => []
    #   }
    #   expected_hash['content_location'].push(returned_data_hash['content_location'][1])
    #   returned_data_hash = data_set.get_data_hash
    #   assert_equal(expected_hash, returned_data_hash.compact.except('id', 'data_type'))
    #
    #   # check consistency of data in DB
    #   assert_equal(1, DataCycleCore::Place.where(template: false).count)
    #   assert_equal(1, DataCycleCore::CreativeWork.where(template: false).count)
    #   assert_equal(1, DataCycleCore::ContentContent.count)
    # end
    #
    # test 'save CreativeWork with two embedded objects having two translations and then delete one translation (full access to embeddedObjects)' do
    #   place_trans_templates = DataCycleCore::Place::Translation.count
    #   cw_trans_templates = DataCycleCore::CreativeWork::Translation.count
    #   # setup data-set with a template
    #   template = DataCycleCore::CreativeWork.where(template: true, template_name: 'Bild2').first
    #   data_set = DataCycleCore::CreativeWork.new
    #   data_set.schema = template.schema
    #   data_set.template_name = template.template_name
    #   data_set.save
    #
    #   # expected de/en hashes for main object
    #   de_expected = {
    #     'access' => [],
    #     'creator' => [],
    #     'headline' => 'Das ist ein Test!',
    #     'description' => 'wooos laft??'
    #   }
    #   en_expected = {
    #     'access' => [],
    #     'creator' => [],
    #     'headline' => 'this is a test!',
    #     'description' => 'wtf is going on???'
    #   }
    #
    #   # save two embedded objects in german translation
    #   data_hash = {
    #     'headline' => 'Das ist ein Test!',
    #     'description' => 'wooos laft??',
    #     'content_location' => [{
    #       'name' => 'Testort',
    #       'longitude' => 13.1,
    #       'latitude' => 25.3
    #     }, {
    #       'name' => '2Testort',
    #       'latitude' => 25.3,
    #       'longitude' => 23.1
    #     }]
    #   }
    #   I18n.with_locale(:de) do
    #     data_set.set_data_hash(data_hash: data_hash)
    #   end
    #   data_set.save
    #
    #   returned_data = I18n.with_locale(:de) { data_set.get_data_hash }
    #   # check for german data-set, two embedded contentLocation // no english data-set
    #   assert_equal(de_expected, returned_data.compact.except('content_location', 'id', 'data_type'))
    #   assert_equal(data_hash['content_location'].size, returned_data['content_location'].size)
    #
    #   assert_nil(I18n.with_locale(:en) { data_set.get_data_hash })
    #
    #   # check what is written to the database
    #   assert_equal(1, DataCycleCore::CreativeWork.where(template: false).count)
    #   assert_equal(1, DataCycleCore::CreativeWork::Translation.count - cw_trans_templates)
    #   assert_equal(2, DataCycleCore::Place.where(template: false).count)
    #   assert_equal(2, DataCycleCore::Place::Translation.count - place_trans_templates)
    #
    #   # prepare a german hash with only one embedded object
    #   returned_data_hash = I18n.with_locale(:de) do
    #     data_set.get_data_hash
    #   end
    #   data_hash2 = returned_data_hash.compact
    #   data_hash2['content_location'] = []
    #   data_hash2['content_location'].push(returned_data_hash['content_location'][1])
    #   ids = data_set.places.ids
    #
    #   # save two embedded objects in english
    #   data_hash_en = {
    #     'headline' => 'this is a test!',
    #     'description' => 'wtf is going on???',
    #     'content_location' => [{
    #       'id' => ids[0],
    #       'name' => 'Testplace'
    #     }, {
    #       'id' => ids[1],
    #       'name' => '2nd Testplace'
    #     }]
    #   }
    #
    #   I18n.with_locale(:en) do
    #     data_set.set_data_hash(data_hash: data_hash_en.compact)
    #     data_set.save
    #   end
    #
    #   # check for two german and englisch data_sets (+ check that they are only translations of the same data-sets)
    #   assert_equal(de_expected, I18n.with_locale(:de) { data_set.get_data_hash.compact.except('content_location', 'id', 'data_type') })
    #   assert_equal(data_hash['content_location'].size, I18n.with_locale(:de) { data_set.get_data_hash.compact['content_location'].size })
    #   assert_equal(en_expected, I18n.with_locale(:en) { data_set.get_data_hash.compact.except('content_location', 'id', 'data_type') })
    #   assert_equal(data_hash_en['content_location'].size, I18n.with_locale(:en) { data_set.get_data_hash.compact['content_location'].size })
    #   de_ids = I18n.with_locale(:de) { data_set.get_data_hash.compact['content_location'].map { |item| item['id'] } }
    #   en_ids = I18n.with_locale(:en) { data_set.get_data_hash.compact['content_location'].map { |item| item['id'] } }
    #   assert_equal(de_ids.sort, en_ids.sort)
    #
    #   # check what is written to the database
    #   assert_equal(1, DataCycleCore::CreativeWork.where(template: false).count)
    #   assert_equal(2, DataCycleCore::CreativeWork::Translation.count - cw_trans_templates)
    #   assert_equal(2, DataCycleCore::Place.where(template: false).count)
    #   assert_equal(4, DataCycleCore::Place::Translation.count - place_trans_templates)
    #
    #   # delete the german translation of one object
    #   I18n.with_locale(:de) do
    #     data_set.set_data_hash(data_hash: data_hash2)
    #     data_set.save
    #   end
    #
    #   de_returned = I18n.with_locale(:de) { data_set.get_data_hash }
    #   en_returned = I18n.with_locale(:en) { data_set.get_data_hash }
    #
    #   de_embedded = de_returned['content_location']
    #   en_embedded = en_returned['content_location']
    #   assert_equal(de_expected, de_returned.compact.except('content_location', 'id', 'data_type'))
    #   assert_equal(en_expected, en_returned.compact.except('content_location', 'id', 'data_type'))
    #   assert_equal(1, de_embedded.count)
    #   assert_equal(2, en_embedded.count)
    #
    #   # check consistency of data in DB
    #   assert_equal(2, DataCycleCore::Place.where(template: false).count)
    #   assert_equal(1, DataCycleCore::CreativeWork.where(template: false).count)
    #   assert_equal(2, DataCycleCore::ContentContent.count)
    # end
    #
    # test 'save CreativeWork with two embedded objects each for every translation (full access to embeddedObjects)' do
    #   # setup data-set with a template
    #   template = DataCycleCore::CreativeWork.where(template: true, template_name: 'BildTest').first
    #   data_set = DataCycleCore::CreativeWork.new
    #   data_set.schema = template.schema
    #   data_set.template_name = template.template_name
    #   data_set.save
    #
    #   # expected de/en hashes for main object
    #   de_expected = {
    #     'access' => [],
    #     'headline' => 'Das ist ein Test!',
    #     'description' => 'wooos laft??',
    #     'accountablePerson' => []
    #   }
    #   en_expected = {
    #     'access' => [],
    #     'headline' => 'this is a test!',
    #     'description' => 'wtf is going on???',
    #     'accountablePerson' => []
    #   }
    #
    #   # save two embedded objects in german translation
    #   data_hash = {
    #     'headline' => 'Das ist ein Test!',
    #     'description' => 'wooos laft??',
    #     'content_location' => [{
    #       'headline' => 'Testort',
    #       'longitude' => 11.1,
    #       'latitude' => 22.2
    #     }, {
    #       'headline' => '2Testort',
    #       'latitude' => 33.3,
    #       'longitude' => 44.4
    #     }]
    #   }
    #   I18n.with_locale(:de) do
    #     data_set.set_data_hash(data_hash: data_hash)
    #   end
    #   data_set.save
    #
    #   returned_data_hash = data_set.get_data_hash.compact
    #   # check for german data-set, two embedded contentLocation // no english data-set
    #   assert_equal(de_expected, I18n.with_locale(:de) { returned_data_hash.except('content_location', 'id', 'data_type') })
    #   assert_equal(data_hash['content_location'].size, I18n.with_locale(:de) { returned_data_hash['content_location'].size })
    #   assert_nil(I18n.with_locale(:en) { data_set.get_data_hash })
    #
    #   # save two embedded objects in english (different locations from the german ones)
    #   data_hash_en = {
    #     'headline' => 'this is a test!',
    #     'description' => 'wtf is going on???',
    #     'content_location' => [{
    #       'id' => returned_data_hash['content_location'].first['id'],
    #       'headline' => 'test place'
    #     }, {
    #       'id' => returned_data_hash['content_location'].last['id'],
    #       'headline' => 'second test place'
    #     }]
    #   }
    #
    #   I18n.with_locale(:en) do
    #     data_set.set_data_hash(data_hash: data_hash_en.compact)
    #     data_set.save
    #   end
    #
    #   # check for two german and englisch data_sets (+ check that they are different data-sets)
    #   assert_equal(de_expected, I18n.with_locale(:de) { data_set.get_data_hash.compact.except('content_location', 'id', 'data_type') })
    #   assert_equal(data_hash['content_location'].size, I18n.with_locale(:de) { data_set.get_data_hash.compact['content_location'].size })
    #   assert_equal(en_expected, I18n.with_locale(:en) { data_set.get_data_hash.compact.except('content_location', 'id', 'data_type') })
    #   assert_equal(data_hash_en['content_location'].size, I18n.with_locale(:en) { data_set.get_data_hash.compact['content_location'].size })
    #   de_ids = I18n.with_locale(:de) { data_set.get_data_hash.compact['content_location'].map { |item| item['id'] } }
    #   en_ids = I18n.with_locale(:en) { data_set.get_data_hash.compact['content_location'].map { |item| item['id'] } }
    #   assert_equal(2, de_ids.size)
    #   assert_equal(2, en_ids.size)
    #   assert_equal(de_ids.min, en_ids.min)
    #   assert_equal(de_ids.sort[1], en_ids.sort[1])
    #
    #   # check consistency of data in DB
    #   assert_equal(2, DataCycleCore::Place.where(template: false).count)
    #   assert_equal(1, DataCycleCore::CreativeWork.where(template: false).count)
    #   assert_equal(2, DataCycleCore::ContentContent.count)
    # end

    test 'save proper CreativeWork data-set with hash method' do
      data_set = DataCycleCore::TestPreparations.data_set_object('Container')
      test_hash = { 'name' => 'Dies ist ein Test!', 'description' => 'wtf is going on???' }
      data_set.set_data_hash(data_hash: test_hash)
      assert_equal(test_hash, data_set.get_data_hash.compact.except(*DataCycleCore::TestPreparations.excepted_attributes('creative_work')))
    end

    test 'save CreativeWork with only Titel' do
      data_set = DataCycleCore::TestPreparations.data_set_object('Container')
      test_hash = { 'name' => 'Dies ist ein Test!' }
      data_set.set_data_hash(data_hash: test_hash)
      assert_equal(test_hash, data_set.get_data_hash.compact.except(*DataCycleCore::TestPreparations.excepted_attributes('creative_work')))
      assert_equal(data_set.cache_key.to_s, "data_cycle_core/things/#{data_set.id}-#{data_set.updated_at.utc.to_s(:usec)}/data_cycle_core/thing/translations/#{data_set.translations.first.id}-#{data_set.translations.first.updated_at.utc.to_s(:usec)}-de")
    end

    test 'save CreativeWork with sub-properties' do
      data_set = DataCycleCore::TestPreparations.data_set_object('Container')
      test_hash = {
        'name' => 'Dies ist ein Test!',
        'validity_period' => {
          'valid_from' => '2017-05-01'.in_time_zone,
          'valid_until' => '2017-06-01'.in_time_zone
        }
      }
      data_set.set_data_hash(data_hash: test_hash)
      assert_equal(test_hash, data_set.get_data_hash.compact.except(*DataCycleCore::TestPreparations.excepted_attributes('creative_work')))
    end

    test 'save CreativeWork with irrelevant sub-properties_tree' do
      data_set = DataCycleCore::TestPreparations.data_set_object('Container')
      test_hash = {
        'name' => 'Dies ist ein Test!',
        'validity_period' => {
          'valid_from' => '2017-05-01'.in_time_zone,
          'valid_until' => '2017-06-01'.in_time_zone
        }
      }
      data_set.set_data_hash(data_hash: test_hash)
      assert_equal(test_hash, data_set.get_data_hash.compact.except(*DataCycleCore::TestPreparations.excepted_attributes('creative_work')))
      data_set.set_data_hash(data_hash: { 'name' => 'Dies ist ein Test!', 'validity_period' => { 'valid_from' => '2017-05-01', 'valid_until' => '2017-06-01' }, 'test' => { 'test1' => 1, 'test2' => 2, 'test3' => { 'hallo' => 'World' } } })
      assert_equal(test_hash, data_set.get_data_hash.compact.except(*DataCycleCore::TestPreparations.excepted_attributes('creative_work')))
    end

    test 'save CreativeWork, Data properly written to jsonb' do
      data_set = DataCycleCore::TestPreparations.data_set_object('Container')
      test_hash = {
        'name' => 'Dies ist ein Test!',
        'validity_period' => {
          'valid_from' => '2017-05-01'.in_time_zone,
          'valid_until' => '2017-06-01'.in_time_zone
        }
      }
      data_set.set_data_hash(data_hash: test_hash)
      assert_equal(test_hash, data_set.get_data_hash.compact.except(*DataCycleCore::TestPreparations.excepted_attributes('creative_work')))
      # TODO: get ridd of metadata...
      assert_equal(test_hash.dig('validity_period', 'valid_from').to_s, data_set.metadata.dig('validity_period', 'valid_from'))
      assert_equal(test_hash.dig('validity_period', 'valid_until').to_s, data_set.metadata.dig('validity_period', 'valid_until'))
      assert_equal(test_hash.dig('validity_period', 'valid_from'), data_set.validity_period.valid_from)
      assert_equal(test_hash.dig('validity_period', 'valid_until'), data_set.validity_period.valid_until)
    end

    test 'save CreativeWork with sub-properties and invalid data' do
      data_set = DataCycleCore::TestPreparations.data_set_object('Container')
      error = data_set.set_data_hash(data_hash: { 'name' => 'Dies ist ein Test!', 'validity_period' => { 'valid_from' => '2017-05-01', 'valid_until' => '2017-16-01' } })
      data_set.save
      assert_equal(2, error[:error].count)
    end
    #
    # # TODO: [patrick]: check if required?
    # # test 'save CreativeWork with sub-properties with wrong name and valid data' do
    # #   template = DataCycleCore::CreativeWork.where(template: true, template_name: 'Thema').first
    # #   data_set = DataCycleCore::CreativeWork.new
    # #   data_set.schema = template.schema
    # #   data_set.template_name = template.template_name
    # #   data_set.save
    # #   data_hash = { 'headline' => 'Dies ist ein Test!', 'validity_period' => { 'date_published' => '2017-05-01', 'validTo' => '2017-06-01' } }
    # #   error = data_set.set_data_hash(data_hash: data_hash)
    # #   assert_equal(1, error[:error].count)
    # # end

    test 'save CreativeWork link to user_id' do
      data_set = DataCycleCore::TestPreparations.data_set_object('Container')
      DataCycleCore::User.create!(
        given_name: 'Test',
        family_name: 'TEST',
        email: "#{SecureRandom.base64(12)}@pixelpoint.at",
        password: 'password'
      )
      current_user = DataCycleCore::User.first
      test_hash = { 'name' => 'Dies ist ein Test!' }
      data_set.set_data_hash(data_hash: test_hash, current_user: current_user)
      assert_equal(test_hash, data_set.get_data_hash.compact.except(*DataCycleCore::TestPreparations.excepted_attributes('creative_work')))
      assert_equal(current_user.id, data_set.updated_by)
    end
    # TODO: move to specific test
    # test 'save Recherche and read back' do
    #   template = DataCycleCore::CreativeWork.where(template: true, template_name: 'Recherche').first
    #   data_set = DataCycleCore::CreativeWork.new
    #   data_set.schema = template.schema
    #   data_set.template_name = template.template_name
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
      image_content = DataCycleCore::TestPreparations.data_set_object('Bild')
      image_content.set_data_hash(data_hash: { 'name' => 'Test3' })

      test_hash = {
        'name' => 'Dies ist ein Test!',
        'description' => 'wtf is going on???',
        'image' => [image_content.id]
      }
      content = DataCycleCore::TestPreparations.data_set_object('Artikel')
      content.save!
      content.set_data_hash(data_hash: test_hash, prevent_history: true)
      assert_equal(test_hash.except('image', 'keywords'), content.get_data_hash.compact.except(*DataCycleCore::TestPreparations.excepted_attributes('creative_work')))
      assert_equal(test_hash['image'], content.image.pluck(:id))

      test_hash['description'] = 'only change description'
      content.set_data_hash(data_hash: { 'description' => test_hash['description'] }, partial_update: true, prevent_history: true)
      assert_equal(test_hash.except('image', 'keywords'), content.get_data_hash.compact.except(*DataCycleCore::TestPreparations.excepted_attributes('creative_work')))
      assert_equal(test_hash['image'], content.image.pluck(:id))
    end
  end
end
