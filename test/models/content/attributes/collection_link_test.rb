# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'

module DataCycleCore
  module Content
    module Attributes
      class CollectionLinkTest < DataCycleCore::TestCases::ActiveSupportTestCase
        before(:all) do
          @user = DataCycleCore::User.first
          @stored_filter = DataCycleCore::StoredFilter.create(name: 'test suche 1', user: @user, language: ['de'])
          @watch_list = DataCycleCore::WatchList.create(full_path: 'test Inhaltssammlung 1', user: @user)
          @content = DataCycleCore::TestPreparations.create_content(
            template_name: 'Entity-With-Collection-Link',
            data_hash: { name: 'Test Organization 1' }
          )
        end

        test 'write collection links with set_data_hash' do
          @content.set_data_hash(data_hash: { collections: [@stored_filter.id, @watch_list.id] })

          assert_equal [@stored_filter.id, @watch_list.id], @content.collections.pluck(:id)
        end
      end
    end
  end
end
