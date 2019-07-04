# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'
require 'minitest/autorun'

module DataCycleCore
  describe DataCycleCore::User do
    subject do
      DataCycleCore::User
    end

    describe 'user methods' do
      let(:admin_user) do
        subject.find_by(email: 'admin@datacycle.at')
      end

      it 'has a full_name' do
        assert_equal("#{admin_user.given_name} #{admin_user.family_name}", admin_user.full_name)
      end

      it 'has a rank sufficient for all roles' do
        ranks = DataCycleCore::Role.pluck(:rank)
        ranks.each do |rank|
          assert_equal(true, admin_user.has_rank?(rank))
        end
      end

      it 'has rank admin' do
        assert_equal(true, admin_user.is_rank?(DataCycleCore::Role.order('rank DESC').first.rank))
      end

      it 'has user group Administrators' do
        assert_equal(true, admin_user.has_user_group?('Administrators'))
      end

      it 'return all users for usergroups' do
        assert_equal([admin_user.id], admin_user.include_groups_user_ids.uniq)
      end

      it 'return des correct role' do
        assert_equal(admin_user.role, admin_user.send(:set_default_role))
      end

      it 'has many representations' do
        person = DataCycleCore::DummyDataHelper.create_data('person')

        admin_user.represented_by << person

        assert_includes admin_user.represented_by, person
        assert_equal admin_user, person.representation_of
        assert_nil person.histories.last.representation_of

        person.set_data_hash(data_hash: { given_name: 'Maxi' }.stringify_keys, current_user: admin_user, partial_update: true)

        assert_equal admin_user, person.histories.first.representation_of
      end
    end
  end
end
