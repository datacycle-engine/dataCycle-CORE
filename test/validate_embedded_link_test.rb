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
            name: "Test",
            email: "test@pixelpoint.at",
            admin: false,
            password:"password"
          )
          uuid = DataCycleCore::User.first.id
          validator = DataCycleCore::MasterData::Validators::EmbeddedLink.new(uuid,template_hash)
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
            name: "Test",
            email: "test@pixelpoint.at",
            admin: false,
            password:"password"
          )
          DataCycleCore::User.create!(
            name: "Test2",
            email: "test2@pixelpoint.at",
            admin: false,
            password:"password"
          )
          uuid = DataCycleCore::User.first.id
          uuid2 = DataCycleCore::User.second.id
          validator = DataCycleCore::MasterData::Validators::EmbeddedLinkArray.new(uuid,template_hash)
          assert_equal(0, validator.error[:error].size)
          assert_equal(0, validator.error[:warning].size)
          validator = DataCycleCore::MasterData::Validators::EmbeddedLinkArray.new([uuid],template_hash)
          assert_equal(0, validator.error[:error].size)
          assert_equal(0, validator.error[:warning].size)
          validator = DataCycleCore::MasterData::Validators::EmbeddedLinkArray.new([uuid,uuid2],template_hash)
          assert_equal(0, validator.error[:error].size)
          assert_equal(0, validator.error[:warning].size)
        end

      end

    end
  end
end
