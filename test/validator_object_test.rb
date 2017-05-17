require 'test_helper'

module DataCycleCore
  module MasterData
    module Validators

      class ObjectTest < ActiveSupport::TestCase

        test "init object validator" do
          error_hash = { error: [], warning: []}
          template_hash = {
            "Greeting" => {
              "label" => "test_string",
              "type" => "string",
              "storage_type" => "string",
              "storage_location" => "content"
            },
            "Anzahl" => {
              "label" => "test_number",
              "type" => "number",
              "storage_type" => "number",
              "storage_location" => "content"
            }
          }
          data_hash = {
              "test_string" => "Hello World!",
              "test_number" => 5
          }
          validator = DataCycleCore::MasterData::Validators::Object.new(data_hash,template_hash)
          assert_equal( error_hash, validator.error)
        end

        test "error wrong type in object validator" do
          template_hash = {
            "Greeting" => {
              "label" => "test_string",
              "type" => "wrong type",
              "storage_type" => "string",
              "storage_location" => "content"
            }
          }
          data_hash = {
              "test_string" => "Hello World!"
          }
          validator = DataCycleCore::MasterData::Validators::Object.new(data_hash,template_hash)
          assert_equal(1, validator.error[:error].size)
          assert_equal(0, validator.error[:warning].size)
        end

        test "no error/ignore additional data given" do
          template_hash = {
            "Greeting" => {
              "label" => "test_string",
              "type" => "string",
              "storage_type" => "string",
              "storage_location" => "content"
            },
            "Anzahl" => {
              "label" => "test_number",
              "type" => "number",
              "storage_type" => "number",
              "storage_location" => "content"
            }
          }
          data_hash = {
              "test_string" => "Hello World!",
              "test_number" => 5,
              "xxx" => "xxx"
          }
          validator = DataCycleCore::MasterData::Validators::Object.new(data_hash,template_hash)
          assert_equal(0, validator.error[:error].size)
          assert_equal(0, validator.error[:warning].size)
        end

        test "warning data missing" do
          template_hash = {
            "Greeting" => {
              "label" => "test_string",
              "type" => "string",
              "storage_type" => "string",
              "storage_location" => "content"
            },
            "Anzahl" => {
              "label" => "test_number",
              "type" => "number",
              "storage_type" => "number",
              "storage_location" => "content"
            }
          }
          data_hash = {
              "test_string" => "Hello World!"
          }
          validator = DataCycleCore::MasterData::Validators::Object.new(data_hash,template_hash)
          assert_equal(0, validator.error[:error].size)
          assert_equal(1, validator.error[:warning].size)
        end

        test "error object definition missing" do
          template_hash = {
            "Greeting" => {
              "label" => "test_string",
              "type" => "string",
              "storage_type" => "string",
              "storage_location" => "content"
            },
            "Anzahl" => {
              "label" => "test_number",
              "type" => "object",
              "storage_location" => "content"
            }
          }
          data_hash = {
              "test_string" => "Hello World!",
              "test_number" => 5
          }
          validator = DataCycleCore::MasterData::Validators::Object.new(data_hash,template_hash)
          assert_equal(1, validator.error[:error].size)
          assert_equal(0, validator.error[:warning].size)
        end

        test "error collecting" do
          template_hash = {
            "Greeting" => {
              "label" => "test_string",
              "type" => "string",
              "storage_type" => "string",
              "storage_location" => "content"
            },
            "Anzahl" => {
              "label" => "test_number",
              "type" => "object",
              "storage_location" => "content",
              "properties" => {
                "test1" => {
                  "label" => "test1",
                  "type" => "string",
                  "storage_type" => "string",
                  "storage_location" => "content"
                },
                "test2" => {
                  "label" => "test2",
                  "type" => "string",
                  "storage_type" => "string",
                  "storage_location" => "content"
                }
              }

            }
          }
          data_hash = {
              "test_string" => 0,
              "test_number" => {
                "test1" => 1,
                "test2" => 2
              }
          }
          validator = DataCycleCore::MasterData::Validators::Object.new(data_hash,template_hash)
          assert_equal(3, validator.error[:error].size)
          assert_equal(0, validator.error[:warning].size)
          data_hash = {
              "test_string" => 0,
              "test_number" => {
                "test1" => 1
              }
          }
          validator = DataCycleCore::MasterData::Validators::Object.new(data_hash,template_hash)
          assert_equal(2, validator.error[:error].size)
          assert_equal(1, validator.error[:warning].size)
        end

      end

    end
  end
end
