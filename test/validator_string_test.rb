require 'test_helper'

module DataCycleCore
  module MasterData
    module Validators

      class StringTest < ActiveSupport::TestCase

        test "init string validator" do
          error_hash = { error: [], warning: []}
          template_hash = {
            "label" => "Test",
            "type" => "string",
            "storage_type" => "string",
            "storage_location" => "content"
          }
          validator = DataCycleCore::MasterData::Validators::String.new("test-string",template_hash)
          assert_equal(error_hash, validator.error)
        end

        test "error when data with wrong class" do
          template_hash = {
            "label" => "Test",
            "type" => "string",
            "storage_type" => "string",
            "storage_location" => "content"
          }
          validator = DataCycleCore::MasterData::Validators::String.new(10,template_hash)
          assert_equal(1, validator.error[:error].size)
          assert_equal(0, validator.error[:warning].size)
        end

        test "warning when no data given" do
          template_hash = {
            "label" => "Test",
            "type" => "string",
            "storage_type" => "string",
            "storage_location" => "content"
          }
          validator = DataCycleCore::MasterData::Validators::String.new(nil,template_hash)
          assert_equal(0, validator.error[:error].size)
          assert_equal(1, validator.error[:warning].size)
        end

        test "no error with all validations correct" do
          template_hash = {
            "label" => "Test",
            "type" => "string",
            "storage_type" => "string",
            "storage_location" => "content",
            "validations" => {
              "minLength" => 20,
              "maxLength" => 40,
              "pattern" => "/[0-9a-f]{8}-([0-9a-f]{4}-){3}[0-9a-f]{12}/",
              "format" => "uuid"
            }
          }
          validator = DataCycleCore::MasterData::Validators::String.new("0001824b-3e51-499c-a088-02db5b5e5cf7",template_hash)
          assert_equal(0, validator.error[:error].size)
          assert_equal(0, validator.error[:warning].size)
        end

        test "error when string not long enough" do
          template_hash = {
            "label" => "Test",
            "type" => "string",
            "storage_type" => "string",
            "storage_location" => "content",
            "validations" => {
              "minLength" => 3
            }
          }
          validator = DataCycleCore::MasterData::Validators::String.new("x",template_hash)
          assert_equal(1, validator.error[:error].size)
          assert_equal(0, validator.error[:warning].size)
        end

        test "error when string too long" do
          template_hash = {
            "label" => "Test",
            "type" => "string",
            "storage_type" => "string",
            "storage_location" => "content",
            "validations" => {
              "maxLength" => 3
            }
          }
          validator = DataCycleCore::MasterData::Validators::String.new("xxxxx",template_hash)
          assert_equal(1, validator.error[:error].size)
          assert_equal(0, validator.error[:warning].size)
        end

        test "error when string does not fit to pattern" do
          template_hash = {
            "label" => "Test",
            "type" => "string",
            "storage_type" => "string",
            "storage_location" => "content",
            "validations" => {
              "pattern" => "/[0-9a-f]{4}-[0-9a-f]{4}/"
            }
          }
          validator = DataCycleCore::MasterData::Validators::String.new("g111-1111",template_hash)
          assert_equal(1, validator.error[:error].size)
          assert_equal(0, validator.error[:warning].size)
          validator = DataCycleCore::MasterData::Validators::String.new("f111-111",template_hash)
          assert_equal(1, validator.error[:error].size)
          assert_equal(0, validator.error[:warning].size)
        end

        test "pass when string does fit to pattern" do
          template_hash = {
            "label" => "Test",
            "type" => "string",
            "storage_type" => "string",
            "storage_location" => "content",
            "validations" => {
              "pattern" => "/[0-9a-f]{4}-[0-9a-f]{4}/"
            }
          }
          validator = DataCycleCore::MasterData::Validators::String.new("abcd-ef01",template_hash)
          assert_equal(0, validator.error[:error].size)
          assert_equal(0, validator.error[:warning].size)
        end

        test "error when data format not supported" do
          template_hash = {
            "label" => "Test",
            "type" => "string",
            "storage_type" => "string",
            "storage_location" => "content",
            "validations" => {
              "format" => "xxx"
            }
          }
          validator = DataCycleCore::MasterData::Validators::String.new("Hello World!" ,template_hash)
          assert_equal(1, validator.error[:error].size)
          assert_equal(0, validator.error[:warning].size)
        end

        test "error when data not fulfill date_time format option" do
          template_hash = {
            "label" => "Test",
            "type" => "string",
            "storage_type" => "string",
            "storage_location" => "content",
            "validations" => {
              "format" => "date_time"
            }
          }
          validator = DataCycleCore::MasterData::Validators::String.new("2017-20-20" ,template_hash)
          assert_equal(1, validator.error[:error].size)
          assert_equal(0, validator.error[:warning].size)
        end

        test "pass for Time.now and Time.zone.now for format date_time" do
          template_hash = {
            "label" => "Test",
            "type" => "string",
            "storage_type" => "string",
            "storage_location" => "content",
            "validations" => {
              "format" => "date_time"
            }
          }
          validator = DataCycleCore::MasterData::Validators::String.new(Time.now.to_s ,template_hash)
          assert_equal(0, validator.error[:error].size)
          assert_equal(0, validator.error[:warning].size)

          validator = DataCycleCore::MasterData::Validators::String.new(Time.zone.now.to_s ,template_hash)
          assert_equal(0, validator.error[:error].size)
          assert_equal(0, validator.error[:warning].size)
        end

        test "pass for time-string for format date_time" do
          template_hash = {
            "label" => "Test",
            "type" => "string",
            "storage_type" => "string",
            "storage_location" => "content",
            "validations" => {
              "format" => "date_time"
            }
          }
          validator = DataCycleCore::MasterData::Validators::String.new("2017-04-04 15:16:38 +0200" ,template_hash)
          assert_equal(0, validator.error[:error].size)
          assert_equal(0, validator.error[:warning].size)
        end

        test "error when data not fulfill date format option" do
          template_hash = {
            "label" => "Test",
            "type" => "string",
            "storage_type" => "string",
            "storage_location" => "content",
            "validations" => {
              "format" => "date"
            }
          }
          validator = DataCycleCore::MasterData::Validators::String.new("2017-13-13" ,template_hash)
          assert_equal(1, validator.error[:error].size)
          assert_equal(0, validator.error[:warning].size)
        end

        test "error when data does not fulfill uuid format option" do
          template_hash = {
            "label" => "Test",
            "type" => "string",
            "storage_type" => "string",
            "storage_location" => "content",
            "validations" => {
              "format" => "uuid"
            }
          }
          validator = DataCycleCore::MasterData::Validators::String.new("2017-13-13" ,template_hash)
          assert_equal(1, validator.error[:error].size)
          assert_equal(0, validator.error[:warning].size)
        end

        test "pass when data does fulfill uuid format option" do
          template_hash = {
            "label" => "Test",
            "type" => "string",
            "storage_type" => "string",
            "storage_location" => "content",
            "validations" => {
              "format" => "uuid"
            }
          }
          validator = DataCycleCore::MasterData::Validators::String.new("0001824b-3e51-499c-a088-02db5b5e5cf7" ,template_hash)
          assert_equal(0, validator.error[:error].size)
          assert_equal(0, validator.error[:warning].size)
        end

        test "fail when data does not fulfill url format option" do
          template_hash = {
            "label" => "Test",
            "type" => "string",
            "storage_type" => "string",
            "storage_location" => "content",
            "validations" => {
              "format" => "url"
            }
          }
          validator = DataCycleCore::MasterData::Validators::String.new("!test" ,template_hash)
          assert_equal(1, validator.error[:error].size)
          assert_equal(0, validator.error[:warning].size)
          validator = DataCycleCore::MasterData::Validators::String.new("test/franz" ,template_hash)
          assert_equal(1, validator.error[:error].size)
          assert_equal(0, validator.error[:warning].size)
          validator = DataCycleCore::MasterData::Validators::String.new("html://test/franz" ,template_hash)
          assert_equal(1, validator.error[:error].size)
          assert_equal(0, validator.error[:warning].size)
          validator = DataCycleCore::MasterData::Validators::String.new("httpx://test/franz" ,template_hash)
          assert_equal(1, validator.error[:error].size)
          assert_equal(0, validator.error[:warning].size)
          validator = DataCycleCore::MasterData::Validators::String.new("http://test.com/franz:aöslkfj" ,template_hash)
          assert_equal(1, validator.error[:error].size)
          assert_equal(0, validator.error[:warning].size)
          validator = DataCycleCore::MasterData::Validators::String.new(8 ,template_hash)
          assert_equal(1, validator.error[:error].size)
          assert_equal(0, validator.error[:warning].size)
          validator = DataCycleCore::MasterData::Validators::String.new(:test ,template_hash)
          assert_equal(1, validator.error[:error].size)
          assert_equal(0, validator.error[:warning].size)
        end

        test "pass when data does fulfill url format option" do
          template_hash = {
            "label" => "Test",
            "type" => "string",
            "storage_type" => "string",
            "storage_location" => "content",
            "validations" => {
              "format" => "url"
            }
          }
          validator = DataCycleCore::MasterData::Validators::String.new("http://www.example.com" ,template_hash)
          assert_equal(0, validator.error[:error].size)
          assert_equal(0, validator.error[:warning].size)
          validator = DataCycleCore::MasterData::Validators::String.new("https://www.example.com" ,template_hash)
          assert_equal(0, validator.error[:error].size)
          assert_equal(0, validator.error[:warning].size)
          validator = DataCycleCore::MasterData::Validators::String.new("http://www.example.com/xxx/yyy" ,template_hash)
          assert_equal(0, validator.error[:error].size)
          assert_equal(0, validator.error[:warning].size)
          validator = DataCycleCore::MasterData::Validators::String.new("http://www.example.com/xxx?test=hallo" ,template_hash)
          assert_equal(0, validator.error[:error].size)
          assert_equal(0, validator.error[:warning].size)
          validator = DataCycleCore::MasterData::Validators::String.new("http://test.com/franz:3000" ,template_hash)
          assert_equal(0, validator.error[:error].size)
          assert_equal(0, validator.error[:warning].size)
        end

        test "passed edge cases for url format option" do
          template_hash = {
            "label" => "Test",
            "type" => "string",
            "storage_type" => "string",
            "storage_location" => "content",
            "validations" => {
              "format" => "url"
            }
          }
          validator = DataCycleCore::MasterData::Validators::String.new("https://www.....example.com" ,template_hash)
          assert_equal(0, validator.error[:error].size)
          assert_equal(0, validator.error[:warning].size)
          validator = DataCycleCore::MasterData::Validators::String.new("http://test.com/franz:99999999999999999" ,template_hash)
          assert_equal(0, validator.error[:error].size)
          assert_equal(0, validator.error[:warning].size)
        end

        test "fail when data does not fulfill boolean format option" do
          template_hash = {
            "label" => "Test",
            "type" => "string",
            "storage_type" => "string",
            "storage_location" => "content",
            "validations" => {
              "format" => "boolean"
            }
          }
          validator = DataCycleCore::MasterData::Validators::String.new("!test" ,template_hash)
          assert_equal(1, validator.error[:error].size)
          assert_equal(0, validator.error[:warning].size)
          validator = DataCycleCore::MasterData::Validators::String.new("test/franz" ,template_hash)
          assert_equal(1, validator.error[:error].size)
          assert_equal(0, validator.error[:warning].size)
          validator = DataCycleCore::MasterData::Validators::String.new("true     s" ,template_hash)
          assert_equal(1, validator.error[:error].size)
          assert_equal(0, validator.error[:warning].size)
          validator = DataCycleCore::MasterData::Validators::String.new("true_" ,template_hash)
          assert_equal(1, validator.error[:error].size)
          assert_equal(0, validator.error[:warning].size)
          validator = DataCycleCore::MasterData::Validators::String.new(5 ,template_hash)
          assert_equal(1, validator.error[:error].size)
          assert_equal(0, validator.error[:warning].size)
        end

        test "pass when data does fulfill boolean format option" do
          template_hash = {
            "label" => "Test",
            "type" => "string",
            "storage_type" => "string",
            "storage_location" => "content",
            "validations" => {
              "format" => "boolean"
            }
          }
          validator = DataCycleCore::MasterData::Validators::String.new("true" ,template_hash)
          assert_equal(0, validator.error[:error].size)
          assert_equal(0, validator.error[:warning].size)
          validator = DataCycleCore::MasterData::Validators::String.new("false" ,template_hash)
          assert_equal(0, validator.error[:error].size)
          assert_equal(0, validator.error[:warning].size)
          validator = DataCycleCore::MasterData::Validators::String.new(" false  " ,template_hash)
          assert_equal(0, validator.error[:error].size)
          assert_equal(0, validator.error[:warning].size)
        end

      end

    end
  end
end
