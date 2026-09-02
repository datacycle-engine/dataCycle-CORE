# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module MasterData
    module Validators
      class CollectionTest < ActiveSupport::TestCase
        def subject
          DataCycleCore::MasterData::Validators::Collection
        end

        def setup
          @user = DataCycleCore::User.first
          @stored_filter = DataCycleCore::StoredFilter.create(name: 'test suche 1', user: @user, language: ['de'])
          @watch_list = DataCycleCore::WatchList.create(full_path: 'test Inhaltssammlung 1', user: @user)
        end

        def validation_hash
          {
            'label' => 'Ersteller',
            'type' => 'collection'
          }
        end

        test 'successfully validates collection without validation' do
          validator = subject.new([@stored_filter.id], validation_hash)

          assert_predicate validator.error[:error], :blank?
          assert_predicate validator.error[:warning], :blank?
        end

        test 'successfully validates collection without api flag with soft_api validation' do
          validator = subject.new([@stored_filter.id], validation_hash.merge({ 'validations' => { 'soft_api' => true } }))

          assert_predicate validator.error[:error], :blank?
          assert_predicate validator.error[:warning], :present?
        end

        test 'successfully validates collection with api flag with soft_api validation' do
          @stored_filter.update(api: true)
          validator = subject.new([@stored_filter.id], validation_hash.merge({ 'validations' => { 'soft_api' => true } }))

          assert_predicate validator.error[:error], :blank?
          assert_predicate validator.error[:warning], :blank?
        end

        test 'rejects a blank collection with required validation' do
          validator = subject.new([], validation_hash.merge({ 'validations' => { 'required' => true } }))

          assert_includes validator.error[:error].values.flatten.pluck(:path), 'validation.errors.required'
        end

        test 'warns about a blank collection with soft_required validation' do
          validator = subject.new([], validation_hash.merge({ 'validations' => { 'soft_required' => true } }))

          assert_predicate validator.error[:error], :blank?
          assert_includes validator.error[:warning].values.flatten.pluck(:path), 'validation.warnings.required'
        end

        test 'successfully validates a present collection with required validation' do
          validator = subject.new([@stored_filter.id], validation_hash.merge({ 'validations' => { 'required' => true } }))

          assert_predicate validator.error[:error], :blank?
          assert_predicate validator.error[:warning], :blank?
        end

        test 'rejects a blank collection with min validation' do
          validator = subject.new([], validation_hash.merge({ 'validations' => { 'min' => 1 } }))

          assert_includes validator.error[:error].values.flatten.pluck(:path), 'validation.errors.min_ref'
        end

        test 'warns about fewer collections than soft_min expects' do
          validator = subject.new([@stored_filter.id], validation_hash.merge({ 'validations' => { 'soft_min' => 2 } }))

          assert_predicate validator.error[:error], :blank?
          assert_includes validator.error[:warning].values.flatten.pluck(:path), 'validation.errors.min_ref'
        end

        test 'rejects more collections than max allows' do
          validator = subject.new([@stored_filter.id, @watch_list.id], validation_hash.merge({ 'validations' => { 'max' => 1 } }))

          assert_includes validator.error[:error].values.flatten.pluck(:path), 'validation.errors.max_ref'
        end

        test 'warns about more collections than soft_max allows' do
          validator = subject.new([@stored_filter.id, @watch_list.id], validation_hash.merge({ 'validations' => { 'soft_max' => 1 } }))

          assert_predicate validator.error[:error], :blank?
          assert_includes validator.error[:warning].values.flatten.pluck(:path), 'validation.errors.max_ref'
        end

        test 'rejects a value that is not an array, relation or string' do
          validator = subject.new(42, validation_hash)

          assert_includes validator.error[:error].values.flatten.pluck(:path), 'validation.errors.data_type'
        end

        test 'rejects references that are not uuid strings' do
          validator = subject.new(['not-a-uuid'], validation_hash)

          assert_includes validator.error[:error].values.flatten.pluck(:path), 'validation.errors.data_format'
        end

        test 'reports references that do not resolve to a collection' do
          validator = subject.new([@watch_list.id, SecureRandom.uuid], validation_hash)

          assert_includes validator.error[:error].values.flatten.pluck(:path), 'validation.errors.not_found'
        end
      end
    end
  end
end
