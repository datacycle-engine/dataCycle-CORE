require 'test_helper'

module DataCycleCore
  class CreativeWorkTest < ActiveSupport::TestCase
    test "CreativeWork exists" do
      data = DataCycleCore::CreativeWork.new
      assert_equal(data.class, DataCycleCore::CreativeWork)
    end

    test "different behaviour for embeddedObject without delete flag" do
      template_cw = DataCycleCore::CreativeWork.count
      template_cwt = DataCycleCore::CreativeWork::Translation.count
      template_p = DataCycleCore::Place.count
      template_pt = DataCycleCore::Place::Translation.count

      template_without_delete = DataCycleCore::CreativeWork.find_by(template: true, headline: "Bild", description: "ImageObject")
      validation_without_delete = template_without_delete.metadata['validation']
      data_set_without = DataCycleCore::CreativeWork.new
      data_set_without.metadata = { 'validation' => validation_without_delete }
      data_set_without.save

      data_hash = {
        "headline" => "Dies ist ein Test!",
        "description" => "wtf is going on???",
        "content_location" => [{
            "name" => "Testort",
            "longitude" => 13.10,
            "latitude" => 25.30
        }]
      }
      error = data_set_without.set_data_hash(data_hash: data_hash)
      data_set_without.save

      returned_data_hash_without = data_set_without.get_data_hash
      expected_hash = {
        "access" => [],
        "headline" => "Dies ist ein Test!",
        "description" => "wtf is going on???",
        "content_location" => [{
          "id" => returned_data_hash_without['content_location'][0]['id'],
          "name" => "Testort",
          "latitude" => 25.3,
          "location" => nil,
          "longitude" => 13.1,
          "external_source_id" => nil
        }]
      }

      assert_equal(expected_hash, returned_data_hash_without.compact.except('id','data_type','data_pool', 'keywords'))
      assert_equal(0, error[:error].count)

      # check consistency of data in DB
      assert_equal(1, DataCycleCore::CreativeWork.count - template_cw)
      assert_equal(1, DataCycleCore::CreativeWork::Translation.count - template_cwt)
      assert_equal(1, DataCycleCore::ContentContent.count)
      assert_equal(2, DataCycleCore::ClassificationContent.count)
      assert_equal(1, DataCycleCore::Place.count - template_p)
      assert_equal(1, DataCycleCore::Place::Translation.count - template_pt)

      assert_equal(1, DataCycleCore::CreativeWork::History.count)
      assert_equal(1, DataCycleCore::CreativeWork::History::Translation.count)
      assert_equal(0, DataCycleCore::ClassificationContent::History.count)
      assert_equal(0, DataCycleCore::ContentContent::History.count)
      assert_equal(0, DataCycleCore::Place::History.count)
      assert_equal(0, DataCycleCore::Place::History::Translation.count)

      returned_data_hash_without["content_location"] = []
      error = data_set_without.set_data_hash(data_hash: returned_data_hash_without)
      data_set_without.save

      returned_again = data_set_without.get_data_hash
      assert_equal(returned_data_hash_without, returned_again)

      # check consistency of data in DB
      assert_equal(1, DataCycleCore::CreativeWork.count - template_cw)
      assert_equal(1, DataCycleCore::CreativeWork::Translation.count - template_cwt)
      assert_equal(0, DataCycleCore::ContentContent.count)
      assert_equal(2, DataCycleCore::ClassificationContent.count)
      assert_equal(1, DataCycleCore::Place.count - template_p)
      assert_equal(1, DataCycleCore::Place::Translation.count - template_pt)

      assert_equal(2, DataCycleCore::CreativeWork::History.count)
      assert_equal(2, DataCycleCore::CreativeWork::History::Translation.count)
      assert_equal(1, DataCycleCore::ContentContent::History.count)
      assert_equal(2, DataCycleCore::ClassificationContent::History.count)
      assert_equal(1, DataCycleCore::Place::History.count)
      assert_equal(1, DataCycleCore::Place::History::Translation.count)
    end

    test "save CreativeWork with embedded object contentLocation, then delete embedded object (last and only one)" do
      template = DataCycleCore::CreativeWork.where(template: true, headline: "BildTest", description: "ImageObject").first
      validation = template.metadata['validation']
      data_set = DataCycleCore::CreativeWork.new
      data_set.metadata = { 'validation' => validation }
      data_set.save
      data_hash = {
        "headline" => "Dies ist ein Test!",
        "description" => "wtf is going on???",
        "content_location" => [{
            "name" => "Testort",
            "longitude" => 13.10,
            "latitude" => 25.30
        }]
      }
      error = data_set.set_data_hash(data_hash: data_hash)
      data_set.save
      returned_data_hash = data_set.get_data_hash

      expected_hash = {
        "access" => [],
        "headline" => "Dies ist ein Test!",
        "description" => "wtf is going on???",
        "content_location" => [{
          "id" => returned_data_hash['content_location'][0]['id'],
          "name" => "Testort",
          "latitude" => 25.3,
          "location" => nil,
          "longitude" => 13.1,
          "external_source_id" => nil
        }]
      }

      assert_equal(expected_hash, returned_data_hash.compact.except('id','data_type'))
      assert_equal(0, error[:error].count)

      # check consistency of data in DB
      assert_equal(1, DataCycleCore::CreativeWork.where(template: false).count)
      assert_equal(1, DataCycleCore::ContentContent.count)
      assert_equal(1, DataCycleCore::Place.where(template: false).count)

      returned_data_hash["content_location"] = []
      error = data_set.set_data_hash(data_hash: returned_data_hash)
      data_set.save
      returned_again = data_set.get_data_hash
      assert_equal(returned_data_hash, returned_again)

      # check consistency of data in DB
      assert_equal(1, DataCycleCore::CreativeWork.where(template: false).count)
      assert_equal(0, DataCycleCore::ContentContent.count)
      assert_equal(0, DataCycleCore::Place.where(template: false).count)
    end

    test "save CreativeWork with embedded object contentLocation, read data with only id given" do
      template = DataCycleCore::CreativeWork.where(template: true, headline: "Bild", description: "ImageObject").first
      validation = template.metadata['validation']
      data_set = DataCycleCore::CreativeWork.new
      data_set.metadata = { 'validation' => validation }
      data_set.save
      data_hash = {
        "headline" => "Dies ist ein Test!",
        "description" => "wtf is going on???",
        "content_location" => [{
            "name" => "Testort",
            "longitude" => 13.10,
            "latitude" => 25.30
        }]
      }
      error = data_set.set_data_hash(data_hash: data_hash)
      data_set.save
      returned_data_hash = data_set.get_data_hash

      expected_hash = {
        "access" => [],
        "headline" => "Dies ist ein Test!",
        "description" => "wtf is going on???",
        "content_location" => [{
          "id" => returned_data_hash['content_location'][0]['id'],
          "name" => "Testort",
          "latitude" => 25.3,
          "location" => nil,
          "longitude" => 13.1,
          "external_source_id" => nil
        }]
      }

      assert_equal(expected_hash, returned_data_hash.compact.except('id', 'data_type', 'keywords', 'data_pool'))
      assert_equal(0, error[:error].count)

      # check consistency of data in DB
      assert_equal(1, DataCycleCore::CreativeWork.where(template: false).count)
      assert_equal(1, DataCycleCore::ContentContent.count)
      assert_equal(1, DataCycleCore::Place.where(template: false).count)

      returned_data_hash["content_location"] = [{'id' => returned_data_hash["content_location"][0]['id']}]
      error = data_set.set_data_hash(data_hash: returned_data_hash)
      data_set.save
      returned_again = data_set.get_data_hash
      assert_equal(expected_hash, returned_again.compact.except('id', 'data_type', 'keywords', 'data_pool'))

      # check consistency of data in DB
      assert_equal(1, DataCycleCore::CreativeWork.where(template: false).count)
      assert_equal(1, DataCycleCore::ContentContent.count)
      assert_equal(1, DataCycleCore::Place.where(template: false).count)
    end

    test "save CreativeWork with embedded object contentLocation, create relation with only id given" do
      # insert a place
      template = DataCycleCore::Place.find_by(template: true, headline: "contentLocation", description: "Place")
      validation = template.metadata['validation']
      data_set_place = DataCycleCore::Place.new
      data_set_place.metadata = { 'validation' => validation }
      data_set_place.save
      place_hash = {
          "name" => "Testort",
          "longitude" => 13.10,
          "latitude" => 25.30
      }
      error = data_set_place.set_data_hash(data_hash: place_hash)
      data_set_place.save
      returned_place = data_set_place.get_data_hash
      place_id = returned_place['id']

      # insert an image and connect it to an existing place
      template = DataCycleCore::CreativeWork.find_by(template: true, headline: "Bild", description: "ImageObject")
      validation = template.metadata['validation']
      data_set = DataCycleCore::CreativeWork.new
      data_set.metadata = { 'validation' => validation }
      data_set.save
      data_hash = {
        "headline" => "Dies ist ein Test!",
        "description" => "wtf is going on???",
        "content_location" => [{ "id" => place_id }]
      }
      error = data_set.set_data_hash(data_hash: data_hash)
      data_set.save

      returned_data_hash = data_set.get_data_hash

      expected_hash = {
        "access" => [],
        "headline" => "Dies ist ein Test!",
        "description" => "wtf is going on???",
        "content_location" => [ returned_place ]
      }

      assert_equal(expected_hash, returned_data_hash.compact.except('id', 'data_type', 'keywords', 'data_pool'))
      assert_equal(0, error[:error].count)

      # check consistency of data in DB
      assert_equal(1, DataCycleCore::CreativeWork.where(template: false).count)
      assert_equal(1, DataCycleCore::ContentContent.count)
      assert_equal(1, DataCycleCore::Place.where(template: false).count)
    end

    test "save CreativeWork without embedded object contentLocation, update CW and create relation with only id given" do
      # insert a place
      template = DataCycleCore::Place.find_by(template: true, headline: "contentLocation", description: "Place")
      validation = template.metadata['validation']
      data_set_place = DataCycleCore::Place.new
      data_set_place.metadata = { 'validation' => validation }
      data_set_place.save
      place_hash = {
          "name" => "Testort",
          "longitude" => 13.10,
          "latitude" => 25.30
      }
      error = data_set_place.set_data_hash(data_hash: place_hash)
      data_set_place.save
      returned_place = data_set_place.get_data_hash
      place_id = returned_place['id']

      # insert an image without connection to a place
      template = DataCycleCore::CreativeWork.find_by(template: true, headline: "Bild", description: "ImageObject")
      validation = template.metadata['validation']
      data_set = DataCycleCore::CreativeWork.new
      data_set.metadata = { 'validation' => validation }
      data_set.save
      data_hash = {
        "headline" => "Dies ist ein Test!",
        "description" => "wtf is going on???",
        "content_location" => []
      }
      error = data_set.set_data_hash(data_hash: data_hash)
      data_set.save

      returned_data_hash = data_set.get_data_hash

      expected_hash = {
        "access" => [],
        "headline" => "Dies ist ein Test!",
        "data_type" => returned_data_hash['data_type'],
        "data_pool" => returned_data_hash['data_pool'],
        "description" => "wtf is going on???",
        "content_location" => []
      }

      assert_equal(expected_hash, returned_data_hash.compact.except('id', 'keywords'))
      assert_equal(0, error[:error].count)

      # check consistency of data in DB
      assert_equal(1, DataCycleCore::CreativeWork.where(template: false).count)
      assert_equal(0, DataCycleCore::ContentContent.count)
      assert_equal(1, DataCycleCore::Place.where(template: false).count)
      assert_equal(2, DataCycleCore::ClassificationContent.count)

      # make relation
      data_hash["content_location"] = [{ "id" => place_id }]
      error = data_set.set_data_hash(data_hash: data_hash)
      data_set.save
      returned_data_hash = data_set.get_data_hash
      expected_hash["content_location"] = [ returned_place ]

      assert_equal(expected_hash, returned_data_hash.compact.except('id', 'keywords'))
      assert_equal(0, error[:error].count)

      # check consistency of data in DB
      assert_equal(1, DataCycleCore::CreativeWork.where(template: false).count)
      assert_equal(1, DataCycleCore::ContentContent.count)
      assert_equal(1, DataCycleCore::Place.where(template: false).count)
    end

    test "save CreativeWork with more than one embedded object contentLocation, delete multiple contentLocations at once" do
      template = DataCycleCore::CreativeWork.where(template: true, headline: "BildTest", description: "ImageObject").first
      validation = template.metadata['validation']
      data_set = DataCycleCore::CreativeWork.new
      data_set.metadata = { 'validation' => validation }
      data_set.save
      data_hash = {
        "headline" => "Dies ist ein Test!",
        "description" => "wtf is going on???",
        "content_location" => [{
          "name" => "Testort",
          "longitude" => 13.1,
          "latitude" => 25.3
        },{
          "name" => "2Testort",
          "latitude" => 25.3,
          "longitude" => 23.1
        },{
          "name" => "3Testort",
          "latitude" => 35.3,
          "longitude" => 33.1
        }]
      }
      error = data_set.set_data_hash(data_hash: data_hash)
      data_set.save

      expected_hash = {
        "access" => [],
        "headline" => "Dies ist ein Test!",
        "description" => "wtf is going on???",
        "content_location" => [{
          "id" => nil,
          "name" => "Testort",
          "latitude" => 25.3,
          "location" => nil,
          "longitude" => 13.1,
          "external_source_id" => nil
        },{
          "id" => nil,
          "name" => "2Testort",
          "latitude" => 25.3,
          "location" => nil,
          "longitude" => 23.1,
          "external_source_id" => nil
        },{
          "id" => nil,
          "name" => "3Testort",
          "latitude" => 35.3,
          "location" => nil,
          "longitude" => 33.1,
          "external_source_id" => nil
        }]
      }

      returned_data_hash = data_set.get_data_hash.compact
      assert_equal(expected_hash.except("content_location"), returned_data_hash.except("content_location","data_type"))
      assert_equal(expected_hash["content_location"].count, returned_data_hash["content_location"].count)

      # check consistency of data in DB
      assert_equal(1, DataCycleCore::CreativeWork.where(template: false).count)
      assert_equal(3, DataCycleCore::ContentContent.count)
      assert_equal(3, DataCycleCore::Place.where(template: false).count)

      # delete all places at once
      returned_data_hash["content_location"] = []
      error = data_set.set_data_hash(data_hash: returned_data_hash)
      data_set.save

      returned_again = data_set.get_data_hash.compact
      expected_hash["content_location"] = []
      assert_equal(expected_hash, returned_data_hash.except("data_type"))

      # check consistency of data in DB
      assert_equal(1, DataCycleCore::CreativeWork.where(template: false).count)
      assert_equal(0, DataCycleCore::ContentContent.count)
      assert_equal(0, DataCycleCore::Place.where(template: false).count)
    end

    test "save CreativeWork with embedded object contentLocation, write, read and write back" do
      template = DataCycleCore::CreativeWork.where(template: true, headline: "Bild", description: "ImageObject").first
      validation = template.metadata['validation']
      data_set = DataCycleCore::CreativeWork.new
      data_set.metadata = { 'validation' => validation }
      data_set.save
      data_hash = {
        "headline" => "Dies ist ein Test!",
        "description" => "wtf is going on???",
        "content_location" => [{
            "name" => "Testort",
            "longitude" => 13.10,
            "latitude" => 25.30
        }]
      }
      error = data_set.set_data_hash(data_hash: data_hash)
      data_set.save

      returned_data_hash = data_set.get_data_hash

      expected_hash = {
        "access" => [],
        "headline" => "Dies ist ein Test!",
        "description" => "wtf is going on???",
        "content_location" => [{
          "id" => returned_data_hash['content_location'][0]['id'],
          "name" => "Testort",
          "latitude" => 25.3,
          "location" => nil,
          "longitude" => 13.1,
          "external_source_id" => nil
        }]
      }

      assert_equal(expected_hash, returned_data_hash.except('id', 'data_type', 'keywords', 'data_pool').compact)
      assert_equal(0, error[:error].count)

      error = data_set.set_data_hash(data_hash: returned_data_hash)
      data_set.save

      returned_again = data_set.get_data_hash
      assert_equal(returned_data_hash, returned_again)

      # check consistency of data in DB
      assert_equal(1, DataCycleCore::Place.where(template: false).count)
      assert_equal(1, DataCycleCore::CreativeWork.where(template: false).count)
      assert_equal(1, DataCycleCore::ContentContent.count)
    end

    test "save CreativeWork with embedded object contentLocation" do
      template = DataCycleCore::CreativeWork.where(template: true, headline: "Bild", description: "ImageObject").first
      validation = template.metadata['validation']
      data_set = DataCycleCore::CreativeWork.new
      data_set.metadata = { 'validation' => validation }
      data_set.save
      data_hash = {
        "headline" => "Dies ist ein Test!",
        "description" => "wtf is going on???",
        "content_location" => [{
            "name" => "Testort",
            "longitude" => 13.10,
            "latitude" => 25.30
        }]
      }
      error = data_set.set_data_hash(data_hash: data_hash)
      expected_hash = {
        "access" => [],
        "headline" => "Dies ist ein Test!",
        "description" => "wtf is going on???",
        "content_location" => [{
          "id" => nil,
          "name" => "Testort",
          "latitude" => 25.3,
          "location" => nil,
          "longitude" => 13.1,
          "external_source_id" => nil
        }]
      }
      data_set.save
      returned_data_hash = data_set.get_data_hash.compact
      expected_hash['content_location'][0]['id'] = returned_data_hash['content_location'][0]['id']
      assert_equal(expected_hash, returned_data_hash.except('id', 'data_type', 'keywords', 'data_pool'))
      assert_equal(0, error[:error].count)

      # check consistency of data in DB
      assert_equal(1, DataCycleCore::Place.where(template: false).count)
      assert_equal(1, DataCycleCore::CreativeWork.where(template: false).count)
      assert_equal(1, DataCycleCore::ContentContent.count)
    end

    test "save CreativeWork with embedded object contentLocation consistency check get(set)=set" do
      template = DataCycleCore::CreativeWork.where(template: true, headline: "BildTest", description: "ImageObject").first
      validation = template.metadata['validation']
      data_set = DataCycleCore::CreativeWork.new
      data_set.metadata = { 'validation' => validation }
      data_set.save
      data_hash = {
        "headline" => "Dies ist ein Test!",
        "description" => "wtf is going on???",
        "content_location" => [{
            "name" => "Testort",
            "longitude" => 13.10,
            "latitude" => 25.30
        }]
      }
      error = data_set.set_data_hash(data_hash: data_hash)
      data_set.save
      error = data_set.set_data_hash(data_hash: data_set.get_data_hash.compact)
      data_set.save
      expected_hash = {
        "access" => [],
        "headline" => "Dies ist ein Test!",
        "description" => "wtf is going on???",
        "content_location" => [{
          "id" => nil,
          "name" => "Testort",
          "latitude" => 25.3,
          "location" => nil,
          "longitude" => 13.1,
          "external_source_id" => nil
        }]
      }
      data_set.save
      returned_data_hash = data_set.get_data_hash.compact
      expected_hash['content_location'][0]['id'] = returned_data_hash['content_location'][0]['id']
      assert_equal(expected_hash, returned_data_hash.except('id','data_type'))
      assert_equal(0, error[:error].count)

      # check consistency of data in DB
      assert_equal(1, DataCycleCore::Place.where(template: false).count)
      assert_equal(1, DataCycleCore::CreativeWork.where(template: false).count)
      assert_equal(1, DataCycleCore::ContentContent.count)
    end

    test "save CreativeWork with more than one embedded object contentLocation" do
      template = DataCycleCore::CreativeWork.where(template: true, headline: "Bild", description: "ImageObject").first
      validation = template.metadata['validation']
      data_set = DataCycleCore::CreativeWork.new
      data_set.metadata = { 'validation' => validation }
      data_set.save
      data_hash = {
        "headline" => "Dies ist ein Test!",
        "description" => "wtf is going on???",
        "content_location" => [{
            "name" => "Testort",
            "longitude" => 13.1,
            "latitude" => 25.3
        },{
          "name" => "2Testort",
          "latitude" => 25.3,
          "longitude" => 23.1,
        }]
      }
      error = data_set.set_data_hash(data_hash: data_hash)
      expected_hash = {
        "access" => [],
        "headline" => "Dies ist ein Test!",
        "description" => "wtf is going on???",
        "content_location" => [{
          "id" => nil,
          "name" => "Testort",
          "latitude" => 25.3,
          "location" => nil,
          "longitude" => 13.1,
          "external_source_id" => nil
        },{
          "id" => nil,
          "name" => "2Testort",
          "latitude" => 25.3,
          "location" => nil,
          "longitude" => 23.1,
          "external_source_id" => nil
        }]
      }
      data_set.save
      returned_data_hash = data_set.get_data_hash.compact
      returned_data_hash['content_location'][0]['id'] = nil
      returned_data_hash['content_location'][1]['id'] = nil
      assert_equal(expected_hash.except("content_location"), returned_data_hash.except("content_location",'id', "data_type", 'keywords', 'data_pool'))
      assert_equal(expected_hash["content_location"].count, returned_data_hash["content_location"].count)

      # check consistency of data in DB
      assert_equal(2, DataCycleCore::Place.where(template: false).count)
      assert_equal(1, DataCycleCore::CreativeWork.where(template: false).count)
      assert_equal(2, DataCycleCore::ContentContent.count)
    end

    test "save CreativeWork with two embedded objects then delete one" do
      template = DataCycleCore::CreativeWork.where(template: true, headline: "BildTest", description: "ImageObject").first
      validation = template.metadata['validation']
      data_set = DataCycleCore::CreativeWork.new
      data_set.metadata = { 'validation' => validation }
      data_set.save
      data_hash = {
        "headline" => "Dies ist ein Test!",
        "description" => "wtf is going on???",
        "content_location" => [{
            "name" => "Testort",
            "longitude" => 13.1,
            "latitude" => 25.3
        },{
          "name" => "2Testort",
          "latitude" => 25.3,
          "longitude" => 23.1,
        }]
      }
      error = data_set.set_data_hash(data_hash: data_hash)
      data_set.save
      returned_data_hash = data_set.get_data_hash
      data_hash2 = returned_data_hash.compact
      data_hash2["content_location"] = []
      data_hash2["content_location"].push(returned_data_hash["content_location"][1])
      error = data_set.set_data_hash(data_hash: data_hash2.compact)
      data_set.save

      expected_hash = {
        "access" => [],
        "headline" => "Dies ist ein Test!",
        "description" => "wtf is going on???",
        "content_location" => []
      }
      expected_hash["content_location"].push(returned_data_hash["content_location"][1])
      returned_data_hash = data_set.get_data_hash
      assert_equal(expected_hash, returned_data_hash.compact.except('id','data_type'))

      # check consistency of data in DB
      assert_equal(1, DataCycleCore::Place.where(template: false).count)
      assert_equal(1, DataCycleCore::CreativeWork.where(template: false).count)
      assert_equal(1, DataCycleCore::ContentContent.count)
    end

    test "save CreativeWork with two embedded objects having two translations and then delete one translation (full access to embeddedObjects)" do
      place_trans_templates = DataCycleCore::Place::Translation.count
      cw_trans_templates = DataCycleCore::CreativeWork::Translation.count
      # setup data-set with a template
      template = DataCycleCore::CreativeWork.where(template: true, headline: "Bild2", description: "ImageObject").first
      validation = template.metadata['validation']
      data_set = DataCycleCore::CreativeWork.new
      data_set.metadata = { 'validation' => validation }
      data_set.save

      # expected de/en hashes for main object
      de_expected = {
        "access" => [],
        "headline" => "Das ist ein Test!",
        "description" => "wooos laft??"
      }
      en_expected = {
        "access" => [],
        "headline" => "this is a test!",
        "description" => "wtf is going on???"
      }

      # save two embedded objects in german translation
      data_hash = {
        "headline" => "Das ist ein Test!",
        "description" => "wooos laft??",
        "content_location" => [{
            "name" => "Testort",
            "longitude" => 13.1,
            "latitude" => 25.3
        },{
          "name" => "2Testort",
          "latitude" => 25.3,
          "longitude" => 23.1,
        }]
      }
      error = I18n.with_locale(:de){
        data_set.set_data_hash(data_hash: data_hash)
      }
      data_set.save

      returned_data = I18n.with_locale(:de){data_set.get_data_hash}
      creative_work_id = returned_data["id"]
      # check for german data-set, two embedded contentLocation // no english data-set
      assert_equal(de_expected, returned_data.compact.except("content_location","id","data_type"))
      assert_equal(data_hash["content_location"].size, returned_data["content_location"].size)

      assert_nil(I18n.with_locale(:en){data_set.get_data_hash})

      # check what is written to the database
      assert_equal(1, DataCycleCore::CreativeWork.where(template: false).count)
      assert_equal(1, DataCycleCore::CreativeWork::Translation.count - cw_trans_templates)
      assert_equal(2, DataCycleCore::Place.where(template: false).count)
      assert_equal(2, DataCycleCore::Place::Translation.count - place_trans_templates)

      # prepare a german hash with only one embedded object
      returned_data_hash = I18n.with_locale(:de){
        data_set.get_data_hash
      }
      data_hash2 = returned_data_hash.compact
      data_hash2["content_location"] = []
      data_hash2["content_location"].push(returned_data_hash["content_location"][1])
      ids = data_set.places.ids

      # save two embedded objects in english
      data_hash_en = {
        "headline" => "this is a test!",
        "description" => "wtf is going on???",
        "content_location" => [{
          "id" => ids[0],
          "name" => "Testplace",
          "longitude" => 13.1,
          "latitude" => 25.3
        },{
          "id" => ids[1],
          "name" => "2nd Testplace",
          "latitude" => 25.3,
          "longitude" => 23.1,
        }]
      }

      error_eng = I18n.with_locale(:en){
        data_set.set_data_hash(data_hash: data_hash_en.compact)
      }
      data_set.save

      # check for two german and englisch data_sets (+ check that they are only translations of the same data-sets)
      assert_equal(de_expected, I18n.with_locale(:de){data_set.get_data_hash.compact.except("content_location","id","data_type")})
      assert_equal(data_hash["content_location"].size, I18n.with_locale(:de){data_set.get_data_hash.compact["content_location"].size})
      assert_equal(en_expected, I18n.with_locale(:en){data_set.get_data_hash.compact.except("content_location","id","data_type")})
      assert_equal(data_hash_en["content_location"].size, I18n.with_locale(:en){data_set.get_data_hash.compact["content_location"].size})
      de_ids = I18n.with_locale(:de){data_set.get_data_hash.compact["content_location"].map{|item| item["id"]}}
      en_ids = I18n.with_locale(:en){data_set.get_data_hash.compact["content_location"].map{|item| item["id"]}}
      assert_equal(de_ids.sort, en_ids.sort)

      # check what is written to the database
      assert_equal(1, DataCycleCore::CreativeWork.where(template: false).count)
      assert_equal(2, DataCycleCore::CreativeWork::Translation.count - cw_trans_templates)
      assert_equal(2, DataCycleCore::Place.where(template: false).count)
      assert_equal(4, DataCycleCore::Place::Translation.count - place_trans_templates)

      # delete the german translation of one object
      error = I18n.with_locale(:de){
        data_set.set_data_hash(data_hash: data_hash2)
      }
      data_set.save

      de_returned = I18n.with_locale(:de){ data_set.get_data_hash }
      en_returned = I18n.with_locale(:en){ data_set.get_data_hash }

      de_embedded = de_returned["content_location"]
      en_embedded = en_returned["content_location"]
      assert_equal(de_expected, de_returned.compact.except("content_location","id","data_type"))
      assert_equal(en_expected, en_returned.compact.except("content_location","id","data_type"))
      assert_equal(1, de_embedded.count)
      assert_equal(2, en_embedded.count)

      # check consistency of data in DB
      assert_equal(2, DataCycleCore::Place.where(template: false).count)
      assert_equal(1, DataCycleCore::CreativeWork.where(template: false).count)
      assert_equal(2, DataCycleCore::ContentContent.count)
    end

    test "save CreativeWork with two embedded objects each for every translation (full access to embeddedObjects)" do
      # setup data-set with a template
      template = DataCycleCore::CreativeWork.where(template: true, headline: "BildTest", description: "ImageObject").first
      validation = template.metadata['validation']
      data_set = DataCycleCore::CreativeWork.new
      data_set.metadata = { 'validation' => validation }
      data_set.save

      # expected de/en hashes for main object
      de_expected = {
        "access" => [],
        "headline" => "Das ist ein Test!",
        "description" => "wooos laft??"
      }
      en_expected = {
        "access" => [],
        "headline" => "this is a test!",
        "description" => "wtf is going on???"
      }

      # save two embedded objects in german translation
      data_hash = {
        "headline" => "Das ist ein Test!",
        "description" => "wooos laft??",
        "content_location" => [{
            "name" => "Testort",
            "longitude" => 13.1,
            "latitude" => 25.3
        },{
          "name" => "2Testort",
          "latitude" => 25.3,
          "longitude" => 23.1,
        }]
      }
      error = I18n.with_locale(:de){
        data_set.set_data_hash(data_hash: data_hash)
      }
      data_set.save

      # check for german data-set, two embedded contentLocation // no english data-set
      assert_equal(de_expected, I18n.with_locale(:de){data_set.get_data_hash.compact.except("content_location","id","data_type")})
      assert_equal(data_hash["content_location"].size, I18n.with_locale(:de){data_set.get_data_hash.compact["content_location"].size})
      assert_nil(I18n.with_locale(:en){data_set.get_data_hash})

      # save two embedded objects in english (different locations from the german ones)
      data_hash_en = {
        "headline" => "this is a test!",
        "description" => "wtf is going on???",
        "content_location" => [{
          "name" => "Testplace",
          "longitude" => 13.1,
          "latitude" => 25.3
        },{
          "name" => "2nd Testplace",
          "latitude" => 25.3,
          "longitude" => 23.1,
        }]
      }

      error_eng = I18n.with_locale(:en){
        data_set.set_data_hash(data_hash: data_hash_en.compact)
      }
      data_set.save

      # check for two german and englisch data_sets (+ check that they are different data-sets)
      assert_equal(de_expected, I18n.with_locale(:de){data_set.get_data_hash.compact.except("content_location","id","data_type")})
      assert_equal(data_hash["content_location"].size, I18n.with_locale(:de){data_set.get_data_hash.compact["content_location"].size})
      assert_equal(en_expected, I18n.with_locale(:en){data_set.get_data_hash.compact.except("content_location","id","data_type")})
      assert_equal(data_hash_en["content_location"].size, I18n.with_locale(:en){data_set.get_data_hash.compact["content_location"].size})
      de_ids = I18n.with_locale(:de){data_set.get_data_hash.compact["content_location"].map{|item| item["id"]}}
      en_ids = I18n.with_locale(:en){data_set.get_data_hash.compact["content_location"].map{|item| item["id"]}}
      assert_equal(2, de_ids.size)
      assert_equal(2, en_ids.size)
      assert_not_equal(de_ids.sort[0], en_ids.sort[0])
      assert_not_equal(de_ids.sort[1], en_ids.sort[1])

      # check consistency of data in DB
      assert_equal(4, DataCycleCore::Place.where(template: false).count)
      assert_equal(1, DataCycleCore::CreativeWork.where(template: false).count)
      assert_equal(4, DataCycleCore::ContentContent.count)
    end

    test "save proper CreativeWork data-set with hash method" do
      template = DataCycleCore::CreativeWork.where(template: true, headline: "Thema", description: "CreativeWork").first
      validation = template.metadata['validation']
      data_set = DataCycleCore::CreativeWork.new
      data_set.metadata = { 'validation' => validation }
      data_set.save
      data_set.set_data_hash(data_hash: {"headline" => "Dies ist ein Test!", "description" => "wtf is going on???"})
      data_set.save
      expected_hash = {
        "headline" => "Dies ist ein Test!",
        "description" => "wtf is going on???",
        "tags"=>[],
        "state"=>[],
        "topics"=>[],
        "markets"=>[],
        "season" => [],
        "kind" => []
      }
      assert_equal(expected_hash, data_set.get_data_hash.compact.except('id', "data_pool", 'permitted_creator'))
    end

    test "save CreativeWork with only Titel" do
      template = DataCycleCore::CreativeWork.where(template: true, headline: "Thema", description: "CreativeWork").first
      validation = template.metadata['validation']
      data_set = DataCycleCore::CreativeWork.new
      data_set.metadata = { 'validation' => validation }
      data_set.save
      data_set.set_data_hash(data_hash: {"headline" => "Dies ist ein Test!"})
      data_set.save
      expected_hash = {
        "headline" => "Dies ist ein Test!",
        "tags"=>[],
        "state"=>[],
        "topics"=>[],
        "markets"=>[],
        "season" => [],
        "kind" => []
      }
      assert_equal(expected_hash, data_set.get_data_hash.compact.except("id","data_pool", 'permitted_creator'))
    end

    test "save CreativeWork with sub-properties" do
      template = DataCycleCore::CreativeWork.where(template: true, headline: "Thema", description: "CreativeWork").first
      validation = template.metadata['validation']
      data_set = DataCycleCore::CreativeWork.new
      data_set.metadata = { 'validation' => validation }
      data_set.save
      data_set.set_data_hash(data_hash: {"headline" => "Dies ist ein Test!", "validity_period" => {"valid_from" => "2017-05-01", "valid_until" => "2017-06-01"}})
      data_set.save
      expected_hash = {
        "headline" => "Dies ist ein Test!",
        "validity_period" => {
          "valid_from" => "2017-05-01",
          "valid_until" => "2017-06-01"
        },
        "tags"=>[],
        "state"=>[],
        "topics"=>[],
        "markets"=>[],
        "season" => [],
        "kind" => []
      }
      assert_equal(expected_hash, data_set.get_data_hash.compact.except("id", "data_pool", 'permitted_creator'))
    end

    test "save CreativeWork with sub-properties_tree" do
      template = DataCycleCore::CreativeWork.where(template: true, headline: "Thema", description: "CreativeWork").first
      validation = template.metadata['validation']
      data_set = DataCycleCore::CreativeWork.new
      data_set.metadata = { 'validation' => validation }
      data_set.save
      error = data_set.set_data_hash(data_hash: {"headline" => "Dies ist ein Test!", "validity_period" => {"valid_from" => "2017-05-01", "valid_until" => "2017-06-01", "test" => {"test1" => 1, "test2" => 2}}})
      data_set.save
      expected_hash = {
        "headline" => "Dies ist ein Test!",
        "validity_period" => {
          "valid_from" => "2017-05-01",
          "valid_until" => "2017-06-01"
        },
        "tags"=>[],
        "state"=>[],
        "topics"=>[],
        "markets"=>[],
        "season" => [],
        "kind" => []
      }

      assert_equal(expected_hash, data_set.get_data_hash.except('id', "data_pool", 'permitted_creator').compact)
      data_set.set_data_hash(data_hash: {"headline" => "Dies ist ein Test!", "validity_period" => {"valid_from" => "2017-05-01", "valid_until" => "2017-06-01"},"test" => {"test1" => 1, "test2" => 2, "test3" => {"hallo" => "World"}} })
      data_set.save
      assert_equal(expected_hash, data_set.get_data_hash.compact.except('id', "data_pool", 'permitted_creator'))
    end

    test "save CreativeWork, Data properly written to metadata" do
      template = DataCycleCore::CreativeWork.where(template: true, headline: "Thema", description: "CreativeWork").first
      validation = template.metadata['validation']
      data_set = DataCycleCore::CreativeWork.new
      data_set.metadata = { 'validation' => validation }
      data_set.save

      expected_hash = {
        "headline" => "Dies ist ein Test!",
        "validity_period" => {
          "valid_from" => "2017-05-01",
          "valid_until" => "2017-06-01"
        },
        "tags"=>[],
        "state"=>[],
        "topics"=>[],
        "markets"=>[],
        "season" => [],
        "kind" => []
      }

      test_data = {
        "headline" => "Dies ist ein Test!",
        "validity_period" => {
          "valid_from" => "2017-05-01",
          "valid_until" => "2017-06-01"
        }
      }
      data_set.set_data_hash(data_hash: test_data)
      data_set.save
      assert_equal(expected_hash, data_set.get_data_hash.compact.except('id',"data_pool", 'permitted_creator'))
      expected_data_hash = {
        "validity_period" => {
          "valid_from" => "2017-05-01",
          "valid_until" => "2017-06-01"
        }
      }
      assert_equal( expected_data_hash, data_set.metadata.except('validation').compact)
    end

    test "save CreativeWork with sub-properties and invalid data" do
      template = DataCycleCore::CreativeWork.where(template: true, headline: "Thema", description: "CreativeWork").first
      validation = template.metadata['validation']
      data_set = DataCycleCore::CreativeWork.new
      data_set.metadata = { 'validation' => validation }
      data_set.save
      error = data_set.set_data_hash(data_hash: {"headline" => "Dies ist ein Test!", "validity_period" => {"valid_from" => "2017-05-01", "valid_until" => "2017-16-01"}})
      data_set.save
      assert_equal(2, error[:error].count)
    end

    test "save CreativeWork with sub-properties with wrong name and valid data" do
      template = DataCycleCore::CreativeWork.where(template: true, headline: "Thema", description: "CreativeWork").first
      validation = template.metadata['validation']
      data_set = DataCycleCore::CreativeWork.new
      data_set.metadata = { 'validation' => validation }
      data_set.save
      data_hash = {"headline" => "Dies ist ein Test!", "validity_period" => {"date_published" => "2017-05-01", "validTo" => "2017-06-01"}}
      error = data_set.set_data_hash(data_hash: data_hash)
      assert_equal(0, error[:error].count)
    end

    test "save CreativeWork link to user_id" do
      template = DataCycleCore::CreativeWork.where(template: true, headline: "Thema", description: "CreativeWork").first
      validation = template.metadata['validation']
      data_set = DataCycleCore::CreativeWork.new
      data_set.metadata = { 'validation' => validation }
      data_set.save
      DataCycleCore::User.create!(
        given_name: 'Test',
        family_name: 'TEST',
        email: "#{SecureRandom.base64(12)}@pixelpoint.at",
        admin: true,
        password: 'password'
      )
      uuid = DataCycleCore::User.first.id
      data_set.set_data_hash(data_hash: {"headline" => "Dies ist ein Test!", "creator" => uuid})
      data_set.save
      expected_hash = {
        "headline" => "Dies ist ein Test!",
        "creator" => uuid,
        "tags"=>[],
        "state"=>[],
        "topics"=>[],
        "markets"=>[],
        "season" => [],
        "kind" => []
      }

      assert_equal(expected_hash, data_set.get_data_hash.compact.except('id', "data_pool", 'permitted_creator'))
    end

    test "save Recherche and read back" do
      template = DataCycleCore::CreativeWork.where(template: true, headline: "Recherche", description: "CreativeWork").first
      validation = template.metadata['validation']
      data_set = DataCycleCore::CreativeWork.new
      data_set.metadata = { 'validation' => validation }
      data_set.save
      DataCycleCore::CreativeWork.create!(headline: "Test")
      uuid = DataCycleCore::CreativeWork.where(headline: "Test").first.id
      DataCycleCore::CreativeWork.create!(headline: "Test2")
      uuid2 = DataCycleCore::CreativeWork.where(headline: "Test2").first.id
      data_set.set_data_hash(data_hash: {"text" => "Dies ist ein Test!", "image" => [uuid,uuid2]})
      data_set.save
      expected_hash = {
        "text" => "Dies ist ein Test!",
        "image" => [uuid,uuid2]
      }
      assert_equal(expected_hash.except('image'), data_set.get_data_hash.compact.except('id',"data_pool",'video', 'image'))
      assert_equal(expected_hash['image'].sort, data_set.get_data_hash['image'].sort)
    end
  end
end
