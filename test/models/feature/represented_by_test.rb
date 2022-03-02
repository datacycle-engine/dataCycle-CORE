# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class RepresentedByTest < ActiveSupport::TestCase
    setup do
      @user = DataCycleCore::User.find_by(email: 'tester@datacycle.at')
      @person = DataCycleCore::DummyDataHelper.create_data('person')
    end

    test 'user has many representations' do
      @user.represented_by << @person

      assert_includes @user.represented_by, @person
      assert_equal @user, @person.representation_of

      @person.set_data_hash(data_hash: { given_name: 'Maxi' }.stringify_keys, current_user: @user, partial_update: true)

      assert_equal @user, @person.histories.first.representation_of
    end
  end
end
