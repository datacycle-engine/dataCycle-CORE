# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class ConceptSchemeLinkChannelTest < ActionCable::Channel::TestCase
    tests DataCycleCore::ConceptSchemeLinkChannel
    include DataCycleCore::MinitestHookHelper

    before(:all) do
      @concept_scheme = DataCycleCore::ConceptScheme.create!(name: 'ConceptSchemeLinkChannel')
    end

    test 'subscribes and streams when the user may link or unlink contents' do
      user = User.find_by(email: 'admin@datacycle.at')
      user.stub(:can?, true) do
        stub_connection current_user: user
        subscribe concept_scheme_id: @concept_scheme.id, key: 'link', collection_id: 'c1'
      end

      assert_predicate subscription, :confirmed?
      assert_has_stream "concept_scheme_link_c1_#{@concept_scheme.id}"
    end

    test 'rejects when the concept scheme does not exist' do
      stub_connection current_user: User.find_by(email: 'admin@datacycle.at')
      subscribe concept_scheme_id: nil, key: 'link', collection_id: 'c1'

      assert_predicate subscription, :rejected?
    end

    test 'rejects without a current_user' do
      stub_connection current_user: nil
      subscribe concept_scheme_id: @concept_scheme.id, key: 'link', collection_id: 'c1'

      assert_predicate subscription, :rejected?
    end
  end
end
