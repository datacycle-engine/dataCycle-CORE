require 'test_helper'

module DataCycleCore
  module MasterData
    module Validators
      class EmbeddedLinkTest < ActiveSupport::TestCase
        test "successful validation of embeddedLink validator" do
          error_hash = { error: [], warning: []}
          template_hash = {
            "label" => "Ersteller",
            "type" => "embeddedLink",
            "type_name" => "users",
            "storage_type" => "string",
            "storage_location" => "metadata"
          }
          DataCycleCore::User.create!(
            given_name: "Test",
            family_name: "TEST",
            email: "SecureRandom.base64(12)@pixelpoint.at",
            admin: false,
            password:"password"
          )
          uuid = DataCycleCore::User.first.id
          validator = DataCycleCore::MasterData::Validators::EmbeddedLink.new(uuid, template_hash)
          assert_equal(error_hash, validator.error)
        end

        test "successful validation of embeddedLinkArray validator" do
          template_hash = {
            "label" => "Ersteller",
            "type" => "embeddedLinkArray",
            "type_name" => "users",
            "storage_type" => "string",
            "storage_location" => "metadata"
          }
          DataCycleCore::User.create!(
            given_name: "Test",
            family_name: "TEST",
            email: "SecureRandom.base64(12)@pixelpoint.at",
            admin: false,
            password:"password"
          )
          DataCycleCore::User.create!(
            given_name: "Test 2",
            family_name: "TEST 2",
            email: "test2@pixelpoint.at",
            admin: false,
            password:"password"
          )
          uuid = DataCycleCore::User.first.id
          uuid2 = DataCycleCore::User.second.id
          validator = DataCycleCore::MasterData::Validators::EmbeddedLinkArray.new(uuid, template_hash)
          assert_equal(0, validator.error[:error].size)
          assert_equal(0, validator.error[:warning].size)
          validator = DataCycleCore::MasterData::Validators::EmbeddedLinkArray.new([uuid], template_hash)
          assert_equal(0, validator.error[:error].size)
          assert_equal(0, validator.error[:warning].size)
          validator = DataCycleCore::MasterData::Validators::EmbeddedLinkArray.new([uuid, uuid2], template_hash)
          assert_equal(0, validator.error[:error].size)
          assert_equal(0, validator.error[:warning].size)
        end

        test "successful validation of embeddedLinkArray validator with min/max given" do
          template_hash = {
            "label" => "Ersteller",
            "type" => "embeddedLinkArray",
            "type_name" => "users",
            "storage_type" => "string",
            "storage_location" => "metadata",
            "validations" => {
              "min" => 1,
              "max" => 5
            }
          }
          DataCycleCore::User.create!(
            given_name: "Test",
            family_name: "TEST",
            email: "SecureRandom.base64(12)@pixelpoint.at",
            admin: false,
            password:"password"
          )
          DataCycleCore::User.create!(
            given_name: "Test 2",
            family_name: "TEST 2",
            email: "test2@pixelpoint.at",
            admin: false,
            password:"password"
          )
          uuid = DataCycleCore::User.first.id
          uuid2 = DataCycleCore::User.second.id
          validator = DataCycleCore::MasterData::Validators::EmbeddedLinkArray.new(uuid, template_hash)
          assert_equal(0, validator.error[:error].size)
          assert_equal(0, validator.error[:warning].size)
          validator = DataCycleCore::MasterData::Validators::EmbeddedLinkArray.new([uuid], template_hash)
          assert_equal(0, validator.error[:error].size)
          assert_equal(0, validator.error[:warning].size)
          validator = DataCycleCore::MasterData::Validators::EmbeddedLinkArray.new([uuid, uuid2], template_hash)
          assert_equal(0, validator.error[:error].size)
          assert_equal(0, validator.error[:warning].size)
        end

        test "unsuccessful validation of embeddedLinkArray validator with min/max given" do
          template_hash = {
            "label" => "Ersteller",
            "type" => "embeddedLinkArray",
            "type_name" => "users",
            "storage_type" => "string",
            "storage_location" => "metadata",
            "validations" => {
              "min" => 2,
              "max" => 3
            }
          }
          DataCycleCore::User.create!(
            given_name: "Test",
            family_name: "TEST",
            email: "SecureRandom.base64(12)@pixelpoint.at",
            admin: false,
            password:"password"
          )
          DataCycleCore::User.create!(
            given_name: "Test 2",
            family_name: "TEST 2",
            email: "test2@pixelpoint.at",
            admin: false,
            password:"password"
          )
          DataCycleCore::User.create!(
            given_name: "Test 3",
            family_name: "TEST 3",
            email: "test3@pixelpoint.at",
            admin: false,
            password:"password"
          )
          DataCycleCore::User.create!(
            given_name: "Test 4",
            family_name: "TEST 4",
            email: "test4@pixelpoint.at",
            admin: false,
            password:"password"
          )
          uuid = DataCycleCore::User.first.id
          uuid2 = DataCycleCore::User.second.id
          uuid3 = DataCycleCore::User.third.id
          uuid4 = DataCycleCore::User.last.id
          validator = DataCycleCore::MasterData::Validators::EmbeddedLinkArray.new(uuid, template_hash)
          assert_equal(1, validator.error[:error].size)
          assert_equal(0, validator.error[:warning].size)
          validator = DataCycleCore::MasterData::Validators::EmbeddedLinkArray.new([uuid], template_hash)
          assert_equal(1, validator.error[:error].size)
          assert_equal(0, validator.error[:warning].size)
          validator = DataCycleCore::MasterData::Validators::EmbeddedLinkArray.new([uuid, uuid2], template_hash)
          assert_equal(0, validator.error[:error].size)
          assert_equal(0, validator.error[:warning].size)
          validator = DataCycleCore::MasterData::Validators::EmbeddedLinkArray.new([uuid, uuid2, uuid3, uuid4], template_hash)
          assert_equal(1, validator.error[:error].size)
          assert_equal(0, validator.error[:warning].size)
        end
      end
    end
  end
end
