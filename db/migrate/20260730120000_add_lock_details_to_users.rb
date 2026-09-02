# frozen_string_literal: true

class AddLockDetailsToUsers < ActiveRecord::Migration[8.0]
  def up
    add_column :users, :locked_by_id, :uuid, if_not_exists: true
    add_index :users, :locked_by_id, if_not_exists: true
    add_column :users, :auto_locked, :boolean, default: false, null: false, if_not_exists: true

    # Locks that already exist cannot tell an automatic lock from a deliberate one, neither column
    # existed yet. A row with locked_at set and failed_attempts past maximum_attempts has exactly
    # two possible origins: devise's automatic lock, or a lock somebody set on top of an automatic
    # lock that was never reset (no successful sign in, no explicit unlock since). The consent task
    # cannot be among them, it only ever locked users with locked_at IS NULL, and a soft delete
    # resets failed_attempts to 0.
    #
    # Only locks that are still within unlock_in are marked automatic and keep expiring on their
    # own - a deliberate lock cannot be among them, since the ui offers unlock, not lock, while a
    # lock is in effect. Everything else keeps auto_locked = false and therefore needs an explicit
    # unlock. This is the fail closed choice: marking stale locks automatic would both clear
    # access_locked? and put them into dc:users:unlock_expired - releasing a lock an admin had set
    # on purpose. The cost is that a genuinely abandoned automatic lock now also needs an unlock;
    # only accounts that never signed in successfully since the lock can be in that state.
    # deleted_at is redundant here (destroy zeroes failed_attempts) and only marks the intended
    # scope: live accounts.
    automatic = execute(<<~SQL.squish).cmd_tuples
      UPDATE users
      SET auto_locked = TRUE
      WHERE deleted_at IS NULL
        AND locked_at IS NOT NULL
        AND failed_attempts >= #{Devise.maximum_attempts.to_i}
        AND locked_at >= #{connection.quote(Devise.unlock_in.ago)}
    SQL

    permanent = select_value(<<~SQL.squish).to_i
      SELECT COUNT(*) FROM users
      WHERE deleted_at IS NULL AND locked_at IS NOT NULL AND auto_locked = FALSE
    SQL

    say "#{automatic} automatic lock(s) keep expiring on their own, #{permanent} lock(s) are now permanent and need an explicit unlock"
  end

  # remove_columns would combine both drops into one ALTER, but it passes no options on to
  # remove_column_for_alter - the if_exists guard would be dropped silently
  # rubocop:disable-next Rails/BulkChangeTable
  def down
    remove_column :users, :auto_locked, if_exists: true
    remove_column :users, :locked_by_id, if_exists: true
  end
end
