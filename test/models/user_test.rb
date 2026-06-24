# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'
require 'minitest/autorun'
require 'helpers/minitest_spec_helper'

module DataCycleCore
  describe DataCycleCore::User do
    include DataCycleCore::MinitestSpecHelper

    subject do
      DataCycleCore::User
    end

    describe 'user methods' do
      let(:admin_user) do
        subject.find_by(email: 'admin@datacycle.at')
      end

      it 'has a full_name' do
        assert_equal("#{admin_user.given_name} #{admin_user.family_name}".squish, admin_user.full_name)
      end

      it 'has a rank sufficient for all roles except system_admin' do
        ranks = DataCycleCore::Role.where.not(name: 'system_admin').pluck(:rank)

        ranks.each do |rank|
          assert(admin_user.has_rank?(rank))
        end
      end

      it 'has rank super_admin' do
        assert(admin_user.is_rank?(DataCycleCore::Role.find_by(name: 'super_admin')&.rank))
      end

      it 'has user group Administrators' do
        assert(admin_user.has_user_group?('Administrators'))
      end

      it 'return all users for usergroups' do
        assert_equal([admin_user.id], admin_user.include_groups_user_ids.uniq)
      end

      it 'return the correct role' do
        assert_equal(admin_user.role, admin_user.send(:set_default_role))
      end

      it 'soft delete resets all attributes' do
        user = DataCycleCore::User.create!(
          given_name: 'Test',
          family_name: 'TEST',
          email: "#{SecureRandom.base64(12)}@pixelpoint.at",
          password: 'password'
        )

        old_password = user.password
        user.destroy!

        assert_equal("u#{user.id}@ano.nym", user.email)
        assert_equal('', user.given_name)
        assert_equal("anonym_#{user.id.first(8)}", user.family_name)
        assert_nil(user.current_sign_in_ip)
        assert_nil(user.last_sign_in_ip)
        assert_not_equal(old_password, user.password)
        assert_predicate(user.locked_at, :present?)
        assert_predicate(user.deleted_at, :present?)

        assert_predicate(user, :persisted?)
        assert_predicate(user.reload.id, :present?)
      end
    end
  end
end
