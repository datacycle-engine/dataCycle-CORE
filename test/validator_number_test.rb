require 'test_helper'

module DataCycleCore
  module MasterData
    module Validators
      class NumberTest < ActiveSupport::TestCase
        test "init number validator" do
          error_hash = { error: [], warning: []}
          template_hash = {
            "label" => "Test",
            "type" => "number",
            "storage_type" => "number",
            "storage_location" => "content"
          }
          validator = DataCycleCore::MasterData::Validators::Number.new(10,template_hash)
          assert_equal(validator.error, error_hash)
        end

        test "error when data with wrong class" do
          error_hash = { error: [], warning: []}
          template_hash = {
            "label" => "Test",
            "type" => "number",
            "storage_type" => "number",
            "storage_location" => "content"
          }
          validator = DataCycleCore::MasterData::Validators::Number.new("10",template_hash)
          assert_equal(validator.error[:error].size, 1)
          assert_equal(validator.error[:warning].size, 0)
        end

        test "warning when no data given" do
          error_hash = { error: [], warning: []}
          template_hash = {
            "label" => "Test",
            "type" => "number",
            "storage_type" => "number",
            "storage_location" => "content"
          }
          validator = DataCycleCore::MasterData::Validators::Number.new(nil,template_hash)
          assert_equal(validator.error[:error].size, 0)
          assert_equal(validator.error[:warning].size, 1)
        end

        test "no error with min, max validations correct" do
          error_hash = { error: [], warning: []}
          template_hash = {
            "label" => "Test",
            "type" => "number",
            "storage_type" => "number",
            "storage_location" => "content",
            "validations" => {
              "min" => 3,
              "max" => 100,
              "format" => "float"
            }
          }
          validator = DataCycleCore::MasterData::Validators::Number.new(50.55,template_hash)
          assert_equal(validator.error[:error].size, 0)
          assert_equal(validator.error[:warning].size, 0)
        end

        test "error when number too small" do
          error_hash = { error: [], warning: []}
          template_hash = {
            "label" => "Test",
            "type" => "number",
            "storage_type" => "number",
            "storage_location" => "content",
            "validations" => {
              "min" => 3
            }
          }
          validator = DataCycleCore::MasterData::Validators::Number.new(1,template_hash)
          assert_equal(validator.error[:error].size, 1)
          assert_equal(validator.error[:warning].size, 0)
        end

        test "error when number too big" do
          error_hash = { error: [], warning: []}
          template_hash = {
            "label" => "Test",
            "type" => "number",
            "storage_type" => "number",
            "storage_location" => "content",
            "validations" => {
              "max" => 3
            }
          }
          validator = DataCycleCore::MasterData::Validators::Number.new(5,template_hash)
          assert_equal(validator.error[:error].size, 1)
          assert_equal(validator.error[:warning].size, 0)
        end

        test "error when data format not supported" do
          error_hash = { error: [], warning: []}
          template_hash = {
            "label" => "Test",
            "type" => "number",
            "storage_type" => "number",
            "storage_location" => "content",
            "validations" => {
              "format" => "xxx"
            }
          }
          validator = DataCycleCore::MasterData::Validators::Number.new(5.333 ,template_hash)
          assert_equal(validator.error[:error].size, 1)
          assert_equal(validator.error[:warning].size, 0)
        end

        test "error when data not fulfill integer format option" do
          error_hash = { error: [], warning: []}
          template_hash = {
            "label" => "Test",
            "type" => "number",
            "storage_type" => "number",
            "storage_location" => "content",
            "validations" => {
              "format" => "integer"
            }
          }
          validator = DataCycleCore::MasterData::Validators::Number.new(5.333 ,template_hash)
          assert_equal(validator.error[:error].size, 1)
          assert_equal(validator.error[:warning].size, 0)
        end

        test "error when data not fulfill float format option" do
          error_hash = { error: [], warning: []}
          template_hash = {
            "label" => "Test",
            "type" => "number",
            "storage_type" => "number",
            "storage_location" => "content",
            "validations" => {
              "format" => "float"
            }
          }
          validator = DataCycleCore::MasterData::Validators::Number.new("5.333E-4" ,template_hash)
          assert_equal(validator.error[:error].size, 1)
          assert_equal(validator.error[:warning].size, 0)
        end

      end
    end
  end
end
