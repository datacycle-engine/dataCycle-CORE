require 'test_helper'

module DataCycleCore
  module MasterData
    module Validators
      class NumberTest < ActiveSupport::TestCase
        test 'init number validator' do
          error_hash = { error: {}, warning: {} }
          template_hash = {
            'label' => 'Test',
            'type' => 'number',
            'storage_type' => 'number',
            'storage_location' => 'content'
          }
          validator = Number.new(10, template_hash)
          assert_equal(error_hash, validator.error)
        end

        test 'error when data with wrong class' do
          template_hash = {
            'label' => 'Test',
            'type' => 'number',
            'storage_type' => 'number',
            'storage_location' => 'content'
          }
          validator = Number.new('10', template_hash)
          assert_equal(1, validator.error[:error].size)
          assert_equal(0, validator.error[:warning].size)
        end

        test 'warning when no data given' do
          template_hash = {
            'label' => 'Test',
            'type' => 'number',
            'storage_type' => 'number',
            'storage_location' => 'content'
          }
          validator = Number.new(nil, template_hash)
          assert_equal(0, validator.error[:error].size)
          assert_equal(1, validator.error[:warning].size)
        end

        test 'no error with min, max validations correct' do
          template_hash = {
            'label' => 'Test',
            'type' => 'number',
            'storage_type' => 'number',
            'storage_location' => 'content',
            'validations' => {
              'min' => 3,
              'max' => 100,
              'format' => 'float'
            }
          }
          validator = Number.new(50.55, template_hash)
          assert_equal(0, validator.error[:error].size)
          assert_equal(0, validator.error[:warning].size)
        end

        test 'error when number too small' do
          template_hash = {
            'label' => 'Test',
            'type' => 'number',
            'storage_type' => 'number',
            'storage_location' => 'content',
            'validations' => {
              'min' => 3
            }
          }
          validator = Number.new(1, template_hash)
          assert_equal(1, validator.error[:error].size)
          assert_equal(0, validator.error[:warning].size)
        end

        test 'error when number too big' do
          template_hash = {
            'label' => 'Test',
            'type' => 'number',
            'storage_type' => 'number',
            'storage_location' => 'content',
            'validations' => {
              'max' => 3
            }
          }
          validator = Number.new(5, template_hash)
          assert_equal(1, validator.error[:error].size)
          assert_equal(0, validator.error[:warning].size)
        end

        test 'error when data format not supported' do
          template_hash = {
            'label' => 'Test',
            'type' => 'number',
            'storage_type' => 'number',
            'storage_location' => 'content',
            'validations' => {
              'format' => 'xxx'
            }
          }
          validator = Number.new(5.333, template_hash)
          assert_equal(1, validator.error[:error].size)
          assert_equal(0, validator.error[:warning].size)
        end

        test 'error when data not fulfill integer format option' do
          template_hash = {
            'label' => 'Test',
            'type' => 'number',
            'storage_type' => 'number',
            'storage_location' => 'content',
            'validations' => {
              'format' => 'integer'
            }
          }
          validator = Number.new(5.333, template_hash)
          assert_equal(1, validator.error[:error].size)
          assert_equal(0, validator.error[:warning].size)
        end

        test 'error when data not fulfill float format option' do
          template_hash = {
            'label' => 'Test',
            'type' => 'number',
            'storage_type' => 'number',
            'storage_location' => 'content',
            'validations' => {
              'format' => 'float'
            }
          }
          validator = Number.new('5.333E-4', template_hash)
          assert_equal(1, validator.error[:error].size)
          assert_equal(0, validator.error[:warning].size)
        end
      end
    end
  end
end
