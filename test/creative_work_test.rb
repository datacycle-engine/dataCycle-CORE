require 'test_helper'

# load template, classifications for all tests
template_yaml = Rails.root.join('..','setup_data','templates.yml')
DataCycleCore::MasterData::ImportTemplates.new.import(template_yaml)
classification_yaml = Rails.root.join('..','setup_data','classifications.yml')
DataCycleCore::MasterData::ImportClassifications.new.import(classification_yaml)

module DataCycleCore
  class CreativeWorkTest < ActiveSupport::TestCase

    test "CreativeWork exists" do
      data = DataCycleCore::CreativeWork.new
      assert_equal(data.class, DataCycleCore::CreativeWork)
    end

    test "save proper CreativeWork data-set with hash method" do
      template = DataCycleCore::CreativeWork.where(template: true, headline: "Content-Einheit", description: "CreativeWork").first
      validation = template.metadata['validation']
      data_set = DataCycleCore::CreativeWork.new
      data_set.metadata = { 'validation' => validation }
      data_set.save
      data_set.set_data_hash({"title" => "Dies ist ein Test!", "description" => "wtf is going on???"})
      data_set.save
      expected_hash = {
        "tags" => [],
        "state" => [],
        "title" => "Dies ist ein Test!",
        "topics" => [],
        "markets" => [],
        "description" => "wtf is going on???"
      }
      assert_equal(expected_hash, data_set.get_data_hash.compact)
    end

    test "save CreativeWork with only Titel" do
      template = DataCycleCore::CreativeWork.where(template: true, headline: "Content-Einheit", description: "CreativeWork").first
      validation = template.metadata['validation']
      data_set = DataCycleCore::CreativeWork.new
      data_set.metadata = { 'validation' => validation }
      data_set.save
      data_set.set_data_hash({"title" => "Dies ist ein Test!"})
      data_set.save
      expected_hash = {
        "tags" => [],
        "state" => [],
        "title" => "Dies ist ein Test!",
        "topics" => [],
        "markets" => []
      }
      assert_equal(expected_hash, data_set.get_data_hash.compact)
    end

    test "save CreativeWork with sub-properties" do
      template = DataCycleCore::CreativeWork.where(template: true, headline: "Content-Einheit", description: "CreativeWork").first
      validation = template.metadata['validation']
      data_set = DataCycleCore::CreativeWork.new
      data_set.metadata = { 'validation' => validation }
      data_set.save
      data_set.set_data_hash({"title" => "Dies ist ein Test!", "validityPeriod" => {"validFrom" => "2017-05-01", "validTo" => "2017-06-01"}})
      data_set.save
      expected_hash = {
        "tags" => [],
        "state" => [],
        "title" => "Dies ist ein Test!",
        "topics" => [],
        "markets" => [],
        "validityPeriod" => {
          "validFrom" => "2017-05-01",
          "validTo" => "2017-06-01"
        }
      }
      assert_equal(expected_hash, data_set.get_data_hash.compact)
    end

    test "save CreativeWork with sub-properties_tree" do
      template = DataCycleCore::CreativeWork.where(template: true, headline: "Content-Einheit", description: "CreativeWork").first
      validation = template.metadata['validation']
      data_set = DataCycleCore::CreativeWork.new
      data_set.metadata = { 'validation' => validation }
      data_set.save
      data_set.set_data_hash({"title" => "Dies ist ein Test!", "validityPeriod" => {"validFrom" => "2017-05-01", "validTo" => "2017-06-01", "test" => {"test1" => 1, "test2" => 2}}})
      data_set.save
      expected_hash = {
        "tags" => [],
        "state" => [],
        "title" => "Dies ist ein Test!",
        "topics" => [],
        "markets" => [],
        "validityPeriod" => {
          "validFrom" => "2017-05-01",
          "validTo" => "2017-06-01"
        }
      }
      assert_equal(expected_hash, data_set.get_data_hash.compact)
      data_set.set_data_hash({"title" => "Dies ist ein Test!", "validityPeriod" => {"validFrom" => "2017-05-01", "validTo" => "2017-06-01"},"test" => {"test1" => 1, "test2" => 2, "test3" => {"hallo" => "World"}} })
      data_set.save
      assert_equal(expected_hash, data_set.get_data_hash.compact)
    end

    test "save CreativeWork with sub-properties and invalid data" do
      template = DataCycleCore::CreativeWork.where(template: true, headline: "Content-Einheit", description: "CreativeWork").first
      validation = template.metadata['validation']
      data_set = DataCycleCore::CreativeWork.new
      data_set.metadata = { 'validation' => validation }
      data_set.save
      error = data_set.set_data_hash({"title" => "Dies ist ein Test!", "validityPeriod" => {"validFrom" => "2017-05-01", "validTo" => "2017-16-01"}})
      assert_equal(1, error[:error].count)
      assert_equal(8, error[:warning].count)
    end

    test "save CreativeWork with sub-properties with wrong name and valid data" do

      template = DataCycleCore::CreativeWork.where(template: true, headline: "Bild", description: "ImageObject").first
      validation = template.metadata['validation']
      data_set = DataCycleCore::CreativeWork.new
      data_set.metadata = { 'validation' => validation }
      data_hash = {"headline" => "Dies ist ein Test!", "validityPeriod" => {"validFrom" => "2017-05-01", "validUntil" => "2017-06-01"}}
      error = data_set.set_data_hash(data_hash)

      assert_equal(1, error[:error].count)
      assert_equal(23, error[:warning].count)
      expected_hash = {
        "headline" => "Dies ist ein Test!",
        "access" => [],
        "validityPeriod" => {
          "datePublished" => nil,
          "expires" => nil
        }
      }
      assert_equal(expected_hash, data_set.get_data_hash.compact)
    end

    test "save CreativeWork link to user_id" do
      template = DataCycleCore::CreativeWork.where(template: true, headline: "Content-Einheit", description: "CreativeWork").first
      validation = template.metadata['validation']
      data_set = DataCycleCore::CreativeWork.new
      data_set.metadata = { 'validation' => validation }
      data_set.save
      DataCycleCore::User.create!(
        name: "Test",
        email: "test@pixelpoint.at",
        admin: false,
        password:"password"
      )
      uuid = DataCycleCore::User.first.id
      data_set.set_data_hash({"title" => "Dies ist ein Test!", "creator" => uuid})
      data_set.save
      expected_hash = {
        "tags" => [],
        "state" => [],
        "title" => "Dies ist ein Test!",
        "topics" => [],
        "markets" => [],
        "creator" => uuid
      }
      assert_equal(expected_hash, data_set.get_data_hash.compact)
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
      data_set.set_data_hash({"text" => "Dies ist ein Test!", "image" => [uuid,uuid2]})
      data_set.save
      expected_hash = {
        "text" => "Dies ist ein Test!",
        "image" => [uuid,uuid2],
        "data_pool" => []
      }
      assert_equal(expected_hash, data_set.get_data_hash.compact)
    end

  end
end
