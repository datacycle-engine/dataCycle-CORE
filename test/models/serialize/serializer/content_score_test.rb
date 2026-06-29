# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Serialize
    module Serializer
      class ContentScoreTest < DataCycleCore::TestCases::ActiveSupportTestCase
        before(:all) do
          @user = DataCycleCore::User.find_by(email: 'tester@datacycle.at')
          @thing = DataCycleCore::TestPreparations.create_content(
            template_name: 'Artikel',
            data_hash: { name: 'ContentScore Article' },
            user: @user
          )
          @watch_list = DataCycleCore::WatchList.create!(name: 'ContentScore WL', full_path: 'ContentScore WL', user_id: @user.id)
          @stored_filter = DataCycleCore::StoredFilter.create!(name: 'ContentScore SF', user_id: @user.id)
        end

        def serializer
          DataCycleCore::Serialize::Serializer::ContentScore
        end

        # render is stubbed so the zip streams without rendering the real xlsx template
        def stub_renderer(&)
          renderer = Class.new { def render(*, **) = 'XLSXBYTES' }.new
          DataCycleCore::ApplicationController.stub(:renderer_with_user, ->(*, **) { renderer }, &)
        end

        # --- flags --------------------------------------------------------------
        test 'translatable? is true' do
          assert_predicate(serializer, :translatable?)
        end

        test 'mime_type is application/zip' do
          assert_equal('application/zip', serializer.mime_type)
        end

        # --- serialize chain (consumes the zip stream) -------------------------
        test 'serialize_thing streams a zip of content scores' do
          stub_renderer do
            collection = serializer.serialize_thing(content: @thing, language: 'de', user: @user)

            assert_kind_of(DataCycleCore::Serialize::SerializedData::ContentCollection, collection)

            bytes = +''
            collection.first.data.each { |chunk| bytes << chunk }

            assert_predicate(bytes, :present?)
          end
        end

        test 'serialize_watch_list and serialize_stored_filter build content collections' do
          stub_renderer do
            assert_kind_of(
              DataCycleCore::Serialize::SerializedData::ContentCollection,
              serializer.serialize_watch_list(content: @watch_list, language: 'de', user: @user)
            )
            assert_kind_of(
              DataCycleCore::Serialize::SerializedData::ContentCollection,
              serializer.serialize_stored_filter(content: @stored_filter, language: 'de', user: @user)
            )
          end
        end
      end
    end
  end
end
