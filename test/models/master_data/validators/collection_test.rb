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
          assert validator.error[:error].blank?
          assert validator.error[:warning].blank?
        end

        test 'successfully validates collection without api flag with soft_api validation' do
          validator = subject.new([@stored_filter.id], validation_hash.merge({ 'validations' => { 'soft_api' => true } }))
          assert validator.error[:error].blank?
          assert validator.error[:warning].present?
        end

        test 'successfully validates collection with api flag with soft_api validation' do
          @stored_filter.update(api: true)
          validator = subject.new([@stored_filter.id], validation_hash.merge({ 'validations' => { 'soft_api' => true } }))
          assert validator.error[:error].blank?
          assert validator.error[:warning].blank?
        end
      end
    end
  end
end
