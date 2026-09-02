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

      it 'builds initials from the name, and from the email only without one' do
        user = subject.new(email: 'mitterer@pixelpoint.at')

        assert_equal('M', user.initials)

        user.given_name = 'Thomas'
        user.family_name = 'Otti'

        assert_equal('TO', user.initials)
      end

      it 'caps initials at two letters' do
        user = subject.new(email: 'org@datacycle.at', name: 'Pixelpoint Multimedia GmbH')

        assert_equal('PM', user.initials)
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

    # minitest/spec context (see top of file) does not provide Rails'
    # assert_not_* aliases, so the minitest-native refute_* methods are required.
    # rubocop:disable-next Rails/RefuteMethods
    describe 'locking' do
      let(:admin_user) do
        subject.find_by(email: 'admin@datacycle.at')
      end

      let(:user) do
        DataCycleCore::User.create!(
          given_name: 'Lock',
          family_name: 'TEST',
          email: "#{SecureRandom.base64(12)}@pixelpoint.at",
          password: 'password'
        )
      end

      # only devise's own path marks a lock automatic, so an automatic lock has to be produced by
      # failing authentication - setting locked_at and failed_attempts by hand does not create one
      def automatically_lock(user)
        Devise.maximum_attempts.times { user.valid_for_authentication? { false } }

        user.reload
      end

      def expire_lock(user)
        user.update_columns(locked_at: Devise.unlock_in.ago - 1.second)

        user.reload
      end

      it 'stores the locking user and keeps the lock after unlock_in' do
        user.lock_access!(locked_by: admin_user)
        user.reload

        assert_equal(admin_user, user.locked_by)
        assert_predicate(user, :lock_set?)
        assert_predicate(user, :locked_by_user?)
        refute_predicate(user, :automatically_locked?)
        refute_predicate(user, :auto_locked?)
        assert_predicate(user, :access_locked?)

        expire_lock(user)

        assert_predicate(user, :access_locked?)
      end

      it 'leaves locked_by empty for automatic locks and expires them after unlock_in' do
        automatically_lock(user)

        assert_nil(user.locked_by_id)
        assert_predicate(user, :auto_locked?)
        assert_predicate(user, :automatically_locked?)
        refute_predicate(user, :locked_by_user?)
        assert_predicate(user, :access_locked?)

        expire_lock(user)

        refute_predicate(user, :access_locked?)
      end

      # sign in paths without a password check (omniauth, api tokens) never reach
      # valid_for_authentication?, so the expired lock has to be cleared here
      it 'clears an expired automatic lock on any sign in' do
        automatically_lock(user)
        expire_lock(user)

        user.active_for_authentication?
        user.reload

        assert_nil(user.locked_at)
        assert_nil(user.locked_by_id)
        refute_predicate(user, :auto_locked?)
        assert_equal(0, user.failed_attempts)
      end

      it 'does not clear a lock set by another user on sign in' do
        user.lock_access!(locked_by: admin_user)
        expire_lock(user)

        refute_predicate(user, :active_for_authentication?)

        user.reload

        assert_predicate(user, :access_locked?)
        assert_equal(admin_user, user.locked_by)
      end

      it 'keeps a lock without an actor permanently' do
        user.lock_access!
        expire_lock(user)

        refute_predicate(user, :automatically_locked?)
        assert_predicate(user, :access_locked?)
      end

      # dc:privacy:lock_users_without_consent locks with no actor, and its base scope
      # (not_effectively_locked) includes users whose automatic lock has already expired - those
      # still carry failed_attempts >= maximum_attempts, because only a successful sign in or an
      # unlock resets the counter. The kind of lock must not be read off that leftover counter.
      it 'keeps a lock without an actor permanent on top of an expired automatic lock' do
        automatically_lock(user)
        expire_lock(user)

        refute_predicate(user, :access_locked?)
        assert_includes(DataCycleCore::User.not_effectively_locked, user)
        assert_equal(Devise.maximum_attempts, user.failed_attempts)

        user.lock_access!
        user.reload

        assert_equal(Devise.maximum_attempts, user.failed_attempts)
        refute_predicate(user, :auto_locked?)
        refute_predicate(user, :automatically_locked?)
        assert_predicate(user, :access_locked?)

        expire_lock(user)

        assert_predicate(user, :access_locked?)
      end

      # the scopes are the sql counterpart of #access_locked? and have to agree with it,
      # otherwise an expired lock keeps hiding the user from lists and dropdowns
      it 'scopes match access_locked? for every kind of lock' do
        expired_automatic_lock = user
        automatically_lock(expired_automatic_lock)
        expire_lock(expired_automatic_lock)

        DataCycleCore::User.find_each do |u|
          assert_equal(
            u.access_locked?,
            DataCycleCore::User.effectively_locked.exists?(u.id),
            "effectively_locked disagrees with access_locked? for #{u.email}"
          )
          assert_equal(
            !u.access_locked?,
            DataCycleCore::User.not_effectively_locked.exists?(u.id),
            "not_effectively_locked disagrees with access_locked? for #{u.email}"
          )
        end

        refute_predicate(expired_automatic_lock.reload, :access_locked?)
        refute_empty(DataCycleCore::User.not_effectively_locked.where(id: expired_automatic_lock.id))
      end

      it 'names the system as the reason for a lock without an actor' do
        user.lock_access!

        assert_equal(
          I18n.t('user.lock_status.system', date: I18n.l(user.locked_at.in_time_zone, locale: :de, format: :history), locale: :de),
          user.lock_status_text(locale: :de)
        )
      end

      it 'names failed sign in attempts as the reason for an automatic lock' do
        automatically_lock(user)

        assert_equal(
          I18n.t('user.lock_status.automatic', date: I18n.l(user.locked_at.in_time_zone, locale: :de, format: :history), locale: :de),
          user.lock_status_text(locale: :de)
        )
      end

      it 'resets locked_at, locked_by and the lock kind on unlock' do
        automatically_lock(user)
        user.unlock_access!
        user.reload

        assert_nil(user.locked_at)
        assert_nil(user.locked_by_id)
        refute_predicate(user, :auto_locked?)
        assert_equal(0, user.failed_attempts)
        refute_predicate(user, :access_locked?)
      end

      # devise counts an attempt on an already locked account and re-locks once the counter passes
      # maximum_attempts, which would push locked_at of a deliberate lock forward
      it 'does not count failed attempts against a lock without an actor' do
        user.lock_access!
        locked_at = Devise.unlock_in.ago - 1.day
        user.update_columns(locked_at:)
        user.reload

        (Devise.maximum_attempts + 1).times do
          refute(user.valid_for_authentication? { true })
        end

        user.reload

        assert_equal(0, user.failed_attempts)
        assert_equal(locked_at.to_i, user.locked_at.to_i)
        refute_predicate(user, :automatically_locked?)
        assert_predicate(user, :access_locked?)
      end

      it 'does not count failed attempts against a lock set by another user' do
        user.lock_access!(locked_by: admin_user)
        user.reload

        (Devise.maximum_attempts + 1).times do
          refute(user.valid_for_authentication? { true })
        end

        assert_equal(0, user.reload.failed_attempts)
        assert_predicate(user, :access_locked?)
      end

      # an automatic lock still has to expire on its own, the guard must not apply to it
      it 'clears an expired automatic lock on the next sign in attempt' do
        automatically_lock(user)
        expire_lock(user)

        assert(user.valid_for_authentication? { true })

        user.reload

        assert_nil(user.locked_at)
        refute_predicate(user, :auto_locked?)
        assert_equal(0, user.failed_attempts)
      end

      # setting a lock again without an actor is reachable from console/rake and must not
      # downgrade a lock somebody set on purpose into a system lock
      it 'keeps the locking user when an existing lock is set again without an actor' do
        user.lock_access!(locked_by: admin_user)
        user.lock_access!
        user.reload

        assert_equal(admin_user, user.locked_by)
        assert_predicate(user, :locked_by_user?)
        refute_predicate(user, :auto_locked?)
      end

      # an explicit nil still clears it, only the absent option is treated as "leave alone"
      it 'clears the locking user when an explicit nil actor is given' do
        user.lock_access!(locked_by: admin_user)
        user.lock_access!(locked_by: nil)
        user.reload

        assert_nil(user.locked_by_id)
        refute_predicate(user, :locked_by_user?)
      end

      # a project may switch unlock_strategy away from :time, then devise expires nothing and
      # the scopes have to follow - otherwise they report a lock access_locked? still holds
      it 'keeps every lock in effect when the time unlock strategy is disabled' do
        automatically_lock(user)
        expire_lock(user)

        DataCycleCore::User.stub(:unlock_strategy, :none) do
          assert_predicate(user, :access_locked?)
          assert_includes(DataCycleCore::User.effectively_locked, user)
          refute_includes(DataCycleCore::User.not_effectively_locked, user)
        end
      end

      # the soft delete keeps the row but User's default_scope hides it, so locked_by is nil
      # while locked_by_id still points at the user who set the lock
      it 'still names the locking user after they have been soft deleted' do
        locking_user = DataCycleCore::User.create!(
          given_name: 'Locking',
          family_name: 'TEST',
          email: "#{SecureRandom.base64(12)}@pixelpoint.at",
          password: 'password'
        )

        user.lock_access!(locked_by: locking_user)
        locking_user.destroy
        user.reload

        assert_nil(user.locked_by)
        assert_equal(locking_user.id, user.locking_user&.id)
        assert_predicate(user, :locked_by_user?)
        assert_includes(user.lock_status_text(locale: :de), locking_user.full_name)
      end

      # locked_by_id can dangle if a user row is removed for real, the reason must not
      # render as "locked by <empty>" then
      it 'falls back to the system reason when the locking user is gone' do
        user.lock_access!(locked_by: admin_user)
        user.update_columns(locked_by_id: SecureRandom.uuid)
        user.reload

        assert_equal(
          I18n.t('user.lock_status.system', date: I18n.l(user.locked_at.in_time_zone, locale: :de, format: :history), locale: :de),
          user.lock_status_text(locale: :de)
        )
      end

      # a nil result has to be held on to as well, otherwise a dangling locked_by_id re-runs the
      # with_deleted fallback on every call - _stored_saved_search reaches it twice per row
      it 'does not query again for an actor that is gone' do
        user.lock_access!(locked_by: admin_user)
        user.update_columns(locked_by_id: SecureRandom.uuid)
        user.reload

        assert_nil(user.locking_user)

        queries = 0
        counter = ->(_n, _s, _f, _i, payload) { queries += 1 if payload[:sql]&.include?('FROM "users"') }

        ActiveSupport::Notifications.subscribed(counter, 'sql.active_record') do
          3.times { user.locking_user }
        end

        assert_equal(0, queries)
      end

      # a soft deleted user is locked deliberately, the lock must not expire after unlock_in
      it 'keeps the lock of a soft deleted user permanently' do
        automatically_lock(user)
        user.destroy

        deleted = DataCycleCore::User.with_deleted.find(user.id)
        deleted.update_columns(locked_at: Devise.unlock_in.ago - 1.second)

        refute_predicate(deleted.reload, :auto_locked?)
        assert_predicate(deleted, :access_locked?)
      end
    end
  end
end
