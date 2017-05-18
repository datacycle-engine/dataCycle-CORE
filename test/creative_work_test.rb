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

    test "save proper CreativeWork data-set" do
      template = DataCycleCore::CreativeWork.where(template: true, headline: "Content-Einheit", description: "CreativeWork").first
      validation = template.metadata['validation']
      data_set = DataCycleCore::CreativeWork.new
      data_set.metadata = { 'validation' => validation }
      data_set.save
      data_set.set_data_type({"Titel" => "Dies ist ein Test!", "Beschreibung" => "wtf is going on???"})
      data_set.save
      expected_hash = {
        "Tags" => [],
        "Bundesland" => [],
        "Titel" => "Dies ist ein Test!",
        "Themenbereiche" => [],
        "Zielmarkt" => [],
        "Beschreibung" => "wtf is going on???"
      }
      assert_equal(expected_hash, data_set.get_data_type.compact)
    end

    test "save CreativeWork with only Titel" do
      template = DataCycleCore::CreativeWork.where(template: true, headline: "Content-Einheit", description: "CreativeWork").first
      validation = template.metadata['validation']
      data_set = DataCycleCore::CreativeWork.new
      data_set.metadata = { 'validation' => validation }
      data_set.save
      data_set.set_data_type({"Titel" => "Dies ist ein Test!"})
      data_set.save
      expected_hash = {
        "Tags" => [],
        "Bundesland" => [],
        "Titel" => "Dies ist ein Test!",
        "Themenbereiche" => [],
        "Zielmarkt" => []
      }
      assert_equal(expected_hash, data_set.get_data_type.compact)
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
      data_set.set_data_type({"Titel" => "Dies ist ein Test!", "Ersteller" => uuid})
      data_set.save
      expected_hash = {
        "Tags" => [],
        "Bundesland" => [],
        "Titel" => "Dies ist ein Test!",
        "Themenbereiche" => [],
        "Zielmarkt" => [],
        "Ersteller" => uuid
      }
      assert_equal(expected_hash, data_set.get_data_type.compact)
    end

    test "save Recherche and read back" do
      template = DataCycleCore::CreativeWork.where(template: true, headline: "Recherche", description: "CreativeWork").first
      ap template
      validation = template.metadata['validation']
      ap validation
      data_set = DataCycleCore::CreativeWork.new
      data_set.metadata = { 'validation' => validation }
      data_set.save
      DataCycleCore::CreativeWork.create!(headline: "Test")
      uuid = DataCycleCore::CreativeWork.where(headline: "Test").first.id
      DataCycleCore::CreativeWork.create!(headline: "Test2")
      uuid2 = DataCycleCore::CreativeWork.where(headline: "Test2").first.id
      data_set.set_data_type({"Text" => "Dies ist ein Test!", "Bilder" => [uuid,uuid2]})
      data_set.save
      expected_hash = {
        "Text" => "Dies ist ein Test!",
        "Bilder" => [uuid,uuid2]
      }
      assert_equal(expected_hash, data_set.get_data_type.compact)
    end

  end
end
