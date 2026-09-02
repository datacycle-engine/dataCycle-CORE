# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class ConceptSchemeLinkChannelTest < ActionCable::Channel::TestCase
    tests DataCycleCore::ConceptSchemeLinkChannel
    include DataCycleCore::MinitestHookHelper

    before(:all) do
      @concept_scheme = DataCycleCore::ConceptScheme.create!(name: 'ConceptSchemeLinkChannel')
    end

    def admin
      DataCycleCore::User.find_by(email: 'admin@datacycle.at')
    end

    # :link_contents/:unlink_contents are granted on DataCycleCore::ClassificationTreeLabel — the record
    # the button's can? checks too — and admin@datacycle.at is the super_admin that grant belongs to.
    # Checking the ConceptScheme instead matched no rule, so the role being offered the action was
    # rejected here and shown a lost-connection error. No can? stub: that is the point of the test.
    test 'subscribes and streams when the user may link or unlink contents' do
      stub_connection current_user: admin
      subscribe concept_scheme_id: @concept_scheme.id, key: 'link', collection_id: 'c1'

      assert_predicate subscription, :confirmed?
      assert_has_stream "concept_scheme_link_c1_#{@concept_scheme.id}"
    end

    test 'resync replays the state a running job broadcast while the socket was down' do
      stream_name = DataCycleCore::ConceptSchemeLinkChannel.stream_name(
        key: 'link', collection_id: 'c1', concept_scheme_id: @concept_scheme.id
      )
      state = { 'collection_id' => 'c1', 'concept_scheme_id' => @concept_scheme.id, 'finished' => true }
      Rails.cache.write(DataCycleCore::ConceptSchemeLinkChannel.state_cache_key(stream_name), state)

      stub_connection current_user: admin
      subscribe concept_scheme_id: @concept_scheme.id, key: 'link', collection_id: 'c1'
      perform :resync

      assert_equal state, transmissions.last
    end

    test 'resync stays quiet without cached state' do
      stub_connection current_user: admin
      subscribe concept_scheme_id: @concept_scheme.id, key: 'link', collection_id: 'c2'
      perform :resync

      assert_empty transmissions
    end

    test 'rejects a role granted neither ability' do
      standard = DataCycleCore::Role.find_by(name: 'standard')
      user = DataCycleCore::User.where(email: 'cslc_standard@datacycle.at').first_or_initialize
      user.update!(given_name: 'Cslc', family_name: 'Standard', password: 'vdr5pmx@juv9BMJ6ujt', role_id: standard.id, confirmed_at: 1.day.ago)

      stub_connection current_user: user
      subscribe concept_scheme_id: @concept_scheme.id, key: 'link', collection_id: 'c1'

      assert_predicate subscription, :rejected?
    end

    test 'rejects when the concept scheme does not exist' do
      stub_connection current_user: admin
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
