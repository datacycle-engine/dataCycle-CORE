# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class ContentLocksControllerTest < DataCycleCore::TestCases::ActionDispatchIntegrationTest
    before(:all) do
      @current_user = User.find_by(email: 'tester@datacycle.at')
      @other_user = User.find_by(email: 'guest@datacycle.at')
      @thing = DataCycleCore::TestPreparations.create_content(
        template_name: 'Artikel',
        data_hash: { 'name' => 'content lock target' }
      )
    end

    setup do
      sign_in(@current_user)
    end

    def create_lock(user)
      DataCycleCore::ContentLock.create!(user:, activitiable: @thing, activity_type: 'content_lock')
    end

    def token_for(lock_ids)
      DataCycleCore::JsonWebToken.encode(payload: { user_id: @current_user.id, lock_ids: Array(lock_ids) }).token
    end

    test 'update touches locks owned by current_user' do
      lock = create_lock(@current_user)
      original = lock.updated_at

      travel 2.seconds do
        patch content_locks_path, params: { token: token_for(lock.id) }
      end

      assert_response :no_content
      assert_operator lock.reload.updated_at, :>, original
    end

    test 'update with an invalid token is a silent no-op' do
      patch content_locks_path, params: { token: 'not-a-valid-jwt' }

      assert_response :no_content
    end

    test 'update leaves locks owned by another user untouched' do
      lock = create_lock(@other_user)

      patch content_locks_path, params: { token: token_for(lock.id) }

      assert_response :no_content
      assert DataCycleCore::ContentLock.exists?(lock.id)
    end

    test 'destroy removes locks owned by current_user' do
      lock = create_lock(@current_user)

      post content_locks_path, params: { token: token_for(lock.id) }

      assert_response :no_content
      assert_not DataCycleCore::ContentLock.exists?(lock.id)
    end

    test 'destroy with blank token is a silent no-op' do
      post content_locks_path, params: { token: '' }

      assert_response :no_content
    end

    test 'destroy leaves locks owned by another user in place' do
      lock = create_lock(@other_user)

      post content_locks_path, params: { token: token_for(lock.id) }

      assert_response :no_content
      assert DataCycleCore::ContentLock.exists?(lock.id)
    end
  end
end
