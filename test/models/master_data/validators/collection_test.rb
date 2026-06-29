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
