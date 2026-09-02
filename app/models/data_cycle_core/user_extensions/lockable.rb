# frozen_string_literal: true

module DataCycleCore
  module UserExtensions
    # Extends Devise::Models::Lockable with the information WHO locked a user and WHICH KIND of
    # lock it is.
    #
    # locked_by_id is set when another user locks this account and stays nil both when devise
    # locks the account itself after too many failed sign in attempts and when a system task
    # (soft delete, missing consent) sets the lock. auto_locked separates those two: only devise's
    # own locks expire after Devise.unlock_in, locks set by a user or by a system task persist
    # until somebody with the :unlock permission removes them.
    #
    # The kind is persisted rather than derived from failed_attempts: that counter survives a lock
    # and is influenced by whoever tries to sign in, so deriving from it let deliberate locks be
    # reclassified into expiring ones.
    module Lockable
      extend ActiveSupport::Concern

      # sql counterpart of #access_locked? - a lock is only in effect as long as it has not
      # expired, and only devise's own automatic locks ever expire
      ACTIVE_LOCK_SQL = <<~SQL.squish
        users.locked_at IS NOT NULL AND NOT (
          users.auto_locked AND users.locked_at < :expires_before
        )
      SQL

      # without the :time unlock strategy devise never expires a lock, so every lock stays in effect
      LOCK_SET_SQL = 'users.locked_at IS NOT NULL'

      included do
        belongs_to :locked_by, class_name: 'DataCycleCore::User', optional: true
        # :nullify only applies to a real destroy - User#destroy is a soft delete and does not run
        # destroy callbacks, so #locking_user resolves soft deleted actors instead
        has_many :locked_users, class_name: 'DataCycleCore::User', foreign_key: :locked_by_id, inverse_of: :locked_by, dependent: :nullify

        scope :effectively_locked, -> { where(active_lock_sql) }
        # where.not wraps the already sanitized sql in NOT (...) without interpolating it again
        scope :not_effectively_locked, -> { where.not(active_lock_sql) }
      end

      class_methods do
        # sql counterpart of #access_locked?. Without the :time unlock strategy devise expires
        # nothing, so the time condition has to be dropped as well - otherwise the scopes would
        # report a lock as expired that access_locked? still considers in effect.
        def active_lock_sql
          return LOCK_SET_SQL unless unlock_strategy_enabled?(:time)

          sanitize_sql([ACTIVE_LOCK_SQL, { expires_before: unlock_in.ago }])
        end
      end

      # a lock has been set, regardless of who set it or if it already expired.
      # for "is this user locked out right now" use devise's #access_locked?
      def lock_set?
        locked_at.present?
      end

      # locked by devise itself after too many failed sign in attempts - the only kind that expires
      def automatically_locked?
        lock_set? && auto_locked?
      end

      # locked by another user
      def locked_by_user?
        lock_set? && locked_by_id.present?
      end

      # the user who set the lock. locked_by goes through User's default_scope and returns nil
      # once that user has been soft deleted, so fall back to a lookup that still finds them.
      # The memo is keyed on locked_by_id instead of using ||=, which would not hold on to a nil -
      # a dangling locked_by_id (actor hard deleted) would re-run the fallback on every call. The
      # key also invalidates itself whenever the lock changes, reload included.
      def locking_user
        return if locked_by_id.blank?
        return @locking_user if @locking_user_id == locked_by_id

        @locking_user_id = locked_by_id
        @locking_user = locked_by || DataCycleCore::User.with_deleted.find_by(id: locked_by_id)
      end

      # accepts an additional :locked_by option holding the user setting the lock,
      # all other options are passed on to Devise
      def lock_access!(opts = {})
        # setting a lock again without naming an actor must not erase who set the lock that is
        # still in effect - reachable from console/rake, the ui only offers unlock while it holds
        self.locked_by_id = opts[:locked_by]&.id if opts.key?(:locked_by) || !lock_set?
        # only devise's own path through #valid_for_authentication? locks automatically
        self.auto_locked = @automatic_lock.present?

        super(opts.except(:locked_by))
      end

      # removes the lock including the information who set it and which kind it was
      def unlock_access!
        self.locked_by_id = nil
        self.auto_locked = false

        super
      end

      # Devise counts a failed attempt for every sign in attempt, even on an account that is
      # already locked. Attempts are only counted while the account is actually reachable, so a
      # deliberate lock neither collects attempts nor reaches devise's re-lock path.
      # access_locked? stays true, so devise keeps reporting :locked instead of :invalid.
      def valid_for_authentication?
        return false if access_locked? && !automatically_locked?

        @automatic_lock = true

        super
      ensure
        @automatic_lock = nil
      end

      # Devise only clears an expired lock in valid_for_authentication?, which is skipped by
      # sign in paths that do not check a password (omniauth, api tokens). active_for_authentication?
      # runs for every sign in, so the lock is reliably cleared instead of lingering in the ui.
      def active_for_authentication?
        unlock_access! if lock_expired?

        super
      end

      # human readable reason for the lock: set by a user, locked automatically after failed
      # sign in attempts or locked by a system task (missing consent, soft delete)
      def lock_status_text(locale: DataCycleCore.ui_locales.first)
        return if locked_at.blank?

        actor = locking_user
        reason = if actor.present?
                   'by_user'
                 elsif automatically_locked?
                   'automatic'
                 else
                   'system'
                 end

        I18n.t(
          "user.lock_status.#{reason}",
          date: I18n.l(locked_at.in_time_zone, locale:, format: :history),
          user: actor&.full_name,
          locale:
        )
      end

      protected

      # only devise's own automatic locks expire, everything else has to be unlocked explicitly
      def lock_expired?
        return false unless automatically_locked?

        super
      end
    end
  end
end
