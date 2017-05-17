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
      template = DataCycleCore::CreativeWork.where(template: true).first
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
      template = DataCycleCore::CreativeWork.where(template: true).first
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

  end
end
