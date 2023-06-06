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
        assert_equal("#{admin_user.given_name} #{admin_user.family_name}".squish, admin_user.full_name)
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
        assert(old_password != user.password)
        assert(user.locked_at.present?)
        assert(user.deleted_at.present?)

        assert(user.persisted?)
        assert(user.reload.id.present?)
      end
    end
  end
end
