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
          assert_equal(validator.error, error_hash)
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
          assert_equal(validator.error[:error].size, 1)
          assert_equal(validator.error[:warning].size, 0)
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
          assert_equal(validator.error[:error].size, 0)
          assert_equal(validator.error[:warning].size, 0)
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
          assert_equal(validator.error[:error].size, 0)
          assert_equal(validator.error[:warning].size, 1)
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
          assert_equal(validator.error[:error].size, 1)
          assert_equal(validator.error[:warning].size, 0)
        end
        
      end

    end
  end
end
