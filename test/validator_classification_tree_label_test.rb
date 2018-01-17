require 'test_helper'

# load classifications
classification_yaml = Rails.root.join('..', 'data_types', 'classifications.yml')
DataCycleCore::MasterData::ImportClassifications.new.import(classification_yaml)

module DataCycleCore
  module MasterData
    module Validators
      class ClassificationTreeLabelTest < ActiveSupport::TestCase
        test "successful validation of classification_tree_label validator" do
          error_hash = { error: [], warning: [] }
          template_hash = {
            "label" => "Bundesland",
            "type" => "classificationTreeLabel",
            "type_name" => "Bundesländer",
            "storage_type" => "classification_creative_works",
            "storage_location" => "classification_relation"
          }
          uuid = DataCycleCore::Classification.where(name: "Kärnten").first.id
          validator = DataCycleCore::MasterData::Validators::ClassificationTreeLabel.new([uuid], template_hash)
          assert_equal(error_hash, validator.error)
        end

        test "warning no uuid given" do
          template_hash = {
            "label" => "Bundesland",
            "type" => "classificationTreeLabel",
            "type_name" => "Bundesländer",
            "storage_type" => "classification_creative_works",
            "storage_location" => "classification_relation"
          }
          validator = DataCycleCore::MasterData::Validators::ClassificationTreeLabel.new(nil, template_hash)
          assert_equal(0, validator.error[:error].size)
          assert_equal(1, validator.error[:warning].size)
          validator = DataCycleCore::MasterData::Validators::ClassificationTreeLabel.new("", template_hash)
          assert_equal(0, validator.error[:error].size)
          assert_equal(1, validator.error[:warning].size)
        end

        test "successful validation one uuid given" do
          error_hash = { error: [], warning: [] }
          template_hash = {
            "label" => "Bundesland",
            "type" => "classificationTreeLabel",
            "type_name" => "Bundesländer",
            "storage_type" => "classification_creative_works",
            "storage_location" => "classification_relation"
          }
          uuid = DataCycleCore::Classification.where(name: "Kärnten").first.id
          validator = DataCycleCore::MasterData::Validators::ClassificationTreeLabel.new(uuid, template_hash)
          assert_equal(error_hash, validator.error)
        end

        test "failure more uuids given than allowed" do
          template_hash = {
            "label" => "Bundesland",
            "type" => "classificationTreeLabel",
            "type_name" => "Bundesländer",
            "storage_type" => "classification_creative_works",
            "storage_location" => "classification_relation",
            "validations" => {
              "max" => 1
            }
          }
          uuid = DataCycleCore::Classification.where(name: "Kärnten").first.id
          uuid2 = DataCycleCore::Classification.where(name: "Steiermark").first.id
          validator = DataCycleCore::MasterData::Validators::ClassificationTreeLabel.new([uuid, uuid2], template_hash)
          assert_equal(1, validator.error[:error].size)
          assert_equal(0, validator.error[:warning].size)
        end

        test "failure not enough uuids given" do
          template_hash = {
            "label" => "Bundesland",
            "type" => "classificationTreeLabel",
            "type_name" => "Bundesländer",
            "storage_type" => "classification_creative_works",
            "storage_location" => "classification_relation",
            "validations" => {
              "min" => 3
            }
          }
          uuid = DataCycleCore::Classification.where(name: "Kärnten").first.id
          uuid2 = DataCycleCore::Classification.where(name: "Steiermark").first.id
          validator = DataCycleCore::MasterData::Validators::ClassificationTreeLabel.new([uuid, uuid2], template_hash)
          assert_equal(1, validator.error[:error].size)
          assert_equal(0, validator.error[:warning].size)
        end

        test "successful validation several uuid's given" do
          error_hash = { error: [], warning: [] }
          template_hash = {
            "label" => "Bundesland",
            "type" => "classificationTreeLabel",
            "type_name" => "Bundesländer",
            "storage_type" => "classification_creative_works",
            "storage_location" => "classification_relation"
          }
          uuid = DataCycleCore::Classification.where(name: "Kärnten").first.id
          uuid2 = DataCycleCore::Classification.where(name: "Steiermark").first.id
          uuid3 = DataCycleCore::Classification.where(name: "Tirol").first.id
          validator = DataCycleCore::MasterData::Validators::ClassificationTreeLabel.new([uuid, uuid2, uuid3], template_hash)
          assert_equal(error_hash, validator.error)
        end

        test "successful validation several uuid's given with min, max validations" do
          error_hash = { error: [], warning: [] }
          template_hash = {
            "label" => "Bundesland",
            "type" => "classificationTreeLabel",
            "type_name" => "Bundesländer",
            "storage_type" => "classification_creative_works",
            "storage_location" => "classification_relation",
            "validations" => {
              "min" => 1,
              "max" => 5
            }
          }
          uuid = DataCycleCore::Classification.where(name: "Kärnten").first.id
          uuid2 = DataCycleCore::Classification.where(name: "Steiermark").first.id
          uuid3 = DataCycleCore::Classification.where(name: "Tirol").first.id
          validator = DataCycleCore::MasterData::Validators::ClassificationTreeLabel.new([uuid, uuid2, uuid3], template_hash)
          assert_equal(error_hash, validator.error)
        end

        test "error for invalid uuid's given in an array" do
          error_hash = { error: [], warning: [] }
          template_hash = {
            "label" => "Bundesland",
            "type" => "classificationTreeLabel",
            "type_name" => "Bundesländer",
            "storage_type" => "classification_creative_works",
            "storage_location" => "classification_relation"
          }
          uuid = DataCycleCore::Classification.where(name: "Kärnten").first.id
          uuid2 = DataCycleCore::Classification.where(name: "Steiermark").first.id
          uuid3 = DataCycleCore::Classification.where(name: "Tirol").first.id
          validator = DataCycleCore::MasterData::Validators::ClassificationTreeLabel.new([uuid, uuid2, 3, uuid3], template_hash)
          assert_equal(1, validator.error[:error].size)
          assert_equal(0, validator.error[:warning].size)
        end

        test "error wrong type_name (tree_label) given for valid uuid" do
          error_hash = { error: [], warning: [] }
          template_hash = {
            "label" => "Bundesland",
            "type" => "classificationTreeLabel",
            "type_name" => "foo",
            "storage_type" => "classification_creative_works",
            "storage_location" => "classification_relation"
          }
          uuid = DataCycleCore::Classification.where(name: "Kärnten").first.id
          validator = DataCycleCore::MasterData::Validators::ClassificationTreeLabel.new(uuid, template_hash)
          assert_equal(1, validator.error[:error].size)
          assert_equal(0, validator.error[:warning].size)
        end

        test "error wrong uuid-format given" do
          error_hash = { error: [], warning: [] }
          template_hash = {
            "label" => "Bundesland",
            "type" => "classificationTreeLabel",
            "type_name" => "Bundesländer",
            "storage_type" => "classification_creative_works",
            "storage_location" => "classification_relation"
          }
          validator = DataCycleCore::MasterData::Validators::ClassificationTreeLabel.new("abcde", template_hash)
          assert_equal(1, validator.error[:error].size)
          assert_equal(0, validator.error[:warning].size)
          validator = DataCycleCore::MasterData::Validators::ClassificationTreeLabel.new(["abcde"], template_hash)
          assert_equal(1, validator.error[:error].size)
          assert_equal(0, validator.error[:warning].size)
          uuid = DataCycleCore::Classification.where(name: "Kärnten").first.id
          validator = DataCycleCore::MasterData::Validators::ClassificationTreeLabel.new([uuid, "abcde"], template_hash)
          assert_equal(1, validator.error[:error].size)
          assert_equal(0, validator.error[:warning].size)
        end

        test "error aggregation for several wrong uuid's given" do
          error_hash = { error: [], warning: [] }
          template_hash = {
            "label" => "Bundesland",
            "type" => "classificationTreeLabel",
            "type_name" => "Bundesländer",
            "storage_type" => "classification_creative_works",
            "storage_location" => "classification_relation"
          }
          uuid = DataCycleCore::Classification.where(name: "Kärnten").first.id
          uuid2 = DataCycleCore::Classification.where(name: "Steiermark").first.id
          validator = DataCycleCore::MasterData::Validators::ClassificationTreeLabel.new([uuid, "abcde", "asödflkjasdfölkj", uuid2, "aöslkfjasdöflj", 3, "asödlkfasödkfj"], template_hash)
          assert_equal(5, validator.error[:error].size)
          assert_equal(0, validator.error[:warning].size)
        end

        test "warning when empty string in array is given as input" do
          error_hash = { error: [], warning: [] }
          template_hash = {
            "label" => "Bundesland",
            "type" => "classificationTreeLabel",
            "type_name" => "Bundesländer",
            "storage_type" => "classification_creative_works",
            "storage_location" => "classification_relation"
          }
          validator = DataCycleCore::MasterData::Validators::ClassificationTreeLabel.new([""], template_hash)
          assert_equal(0, validator.error[:error].size)
          assert_equal(1, validator.error[:warning].size)
        end
      end
    end
  end
end
