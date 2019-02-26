# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Content
    module Attributes
      class EmbeddedMulitLanguageTest < ActiveSupport::TestCase
        def setup
          # insert embedded (embedded includes linked)
          embedded_multiling = DataCycleCore::TestPreparations.data_set_object('Embedded-Creative-Work-2')
          embedded_multiling.save
          embedded_multiling.set_data_hash(data_hash: { 'name' => 'Deutsch' }, prevent_history: true)
          I18n.with_locale(:en) { embedded_multiling.set_data_hash(data_hash: { 'name' => 'English' }, prevent_history: true) }

          @data_set = DataCycleCore::TestPreparations.data_set_object('Embedded-Entity-Creative-Work-1')
          @data_set.save
          @data_set.set_data_hash(data_hash: { 'name' => 'Deutsch' }, prevent_history: true)
          I18n.with_locale(:en) { @data_set.set_data_hash(data_hash: { 'name' => 'English', 'embedded_creative_work' => [{ 'id' => embedded_multiling.id }] }, prevent_history: true) }

          assert_equal([:de, :en], @data_set.available_locales.sort)
          assert_equal([:de, :en], embedded_multiling.available_locales.sort)

          # check consistency of data in DB
          assert_equal(1, DataCycleCore::Thing.where(template: false, template_name: 'Embedded-Creative-Work-2').count)
          assert_equal(1, DataCycleCore::Thing.where(template: false, template_name: 'Embedded-Entity-Creative-Work-1').count)
          assert_equal(1, DataCycleCore::ContentContent.count)
        end

        test 'delete object with emedded - one embedded in two languages' do
          data_set = @data_set
          data_set.destroy_content(save_history: false)

          # check consistency of data in DB
          assert_equal(0, DataCycleCore::Thing.where(template: false, template_name: 'Embedded-Creative-Work-2').count)
          assert_equal(0, DataCycleCore::Thing.where(template: false, template_name: 'Embedded-Entity-Creative-Work-1').count)
          assert_equal(0, DataCycleCore::ContentContent.count)
        end

        test 'delete object with emedded (language specific) - one embedded in two languages' do
          data_set = @data_set
          # byebug
          data_set.destroy_content(save_history: false, destroy_locale: true)

          # check consistency of data in DB
          assert_equal(1, DataCycleCore::Thing.where(template: false, template_name: 'Embedded-Creative-Work-2').count)
          assert_equal(1, DataCycleCore::Thing.where(template: false, template_name: 'Embedded-Entity-Creative-Work-1').count)
          assert_equal(1, DataCycleCore::ContentContent.count)
        end

        test 'delete object with emedded (language specific, one by one) - one embedded in two languages' do
          data_set = @data_set
          # byebug
          I18n.with_locale(:en) { data_set.destroy_content(save_history: false, destroy_locale: true) }
          assert_equal(1, DataCycleCore::Thing.where(template: false, template_name: 'Embedded-Creative-Work-2').count)
          assert_equal(1, DataCycleCore::Thing.where(template: false, template_name: 'Embedded-Entity-Creative-Work-1').count)
          assert_equal(1, DataCycleCore::ContentContent.count)
          assert_equal(1, data_set.available_locales.size)
          assert_equal(1, DataCycleCore::Thing.where(template: false, template_name: 'Embedded-Entity-Creative-Work-1').first.available_locales.size)

          I18n.with_locale(:de) { data_set.destroy_content(save_history: false, destroy_locale: true) }
          assert_equal(0, DataCycleCore::Thing.where(template: false, template_name: 'Embedded-Creative-Work-2').count)
          assert_equal(0, DataCycleCore::Thing.where(template: false, template_name: 'Embedded-Entity-Creative-Work-1').count)
          assert_equal(0, DataCycleCore::ContentContent.count)
        end

        # test 'delete object with emedded - one embedded in one language' do
        #   data_set = @data_set
        #   data_set.destroy_content(save_history: false)
        #
        #   # check consistency of data in DB
        #   assert_equal(0, DataCycleCore::Thing.where(template: false, template_name: 'Embedded-Creative-Work-2').count)
        #   assert_equal(0, DataCycleCore::Thing.where(template: false, template_name: 'Embedded-Entity-Creative-Work-1').count)
        #   assert_equal(0, DataCycleCore::ContentContent.count)
        # end
        #
        # test 'delete object with emedded (language specific) - one embedded in one language' do
        #   data_set = @data_set
        #   data_set.destroy_content(save_history: false, destroy_locale: true)
        #
        #   # check consistency of data in DB
        #   assert_equal(0, DataCycleCore::Thing.where(template: false, template_name: 'Embedded-Creative-Work-2').count)
        #   assert_equal(0, DataCycleCore::Thing.where(template: false, template_name: 'Embedded-Entity-Creative-Work-1').count)
        #   assert_equal(0, DataCycleCore::ContentContent.count)
        # end
        #
        # test 'do nothing for delete object with emedded (language specific in other language) - one embedded in one language' do
        #   data_set = @data_set
        #   I18n.with_locale(:en) { data_set.destroy_content(save_history: false, destroy_locale: true) }
        #
        #   # check consistency of data in DB
        #   assert_equal(1, DataCycleCore::Thing.where(template: false, template_name: 'Embedded-Creative-Work-2').count)
        #   assert_equal(1, DataCycleCore::Thing.where(template: false, template_name: 'Embedded-Entity-Creative-Work-1').count)
        #   assert_equal(1, DataCycleCore::ContentContent.count)
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
      end
    end
  end
end
