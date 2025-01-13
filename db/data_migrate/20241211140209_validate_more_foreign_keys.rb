# frozen_string_literal: true

class ValidateMoreForeignKeys < ActiveRecord::Migration[7.1]
  # uncomment the following line to disable transactions
  # disable_ddl_transaction!

  def up
    output = execute <<-SQL.squish
      SET LOCAL statement_timeout = 0;

      DELETE FROM searches
      WHERE NOT EXISTS (
          SELECT 1
          FROM things
          WHERE things.id = searches.content_data_id
        );
    SQL

    puts "searches -> things (#{output.count})" # rubocop:disable Rails/Output

    validate_foreign_key :searches, :things, column: :content_data_id

    output = execute <<-SQL.squish
      SET LOCAL statement_timeout = 0;

      DELETE FROM schedules
      WHERE NOT EXISTS (
          SELECT 1
          FROM things
          WHERE things.id = schedules.thing_id
        );
    SQL

    puts "schedules -> things (#{output.count})" # rubocop:disable Rails/Output

    validate_foreign_key :schedules, :things, column: :thing_id

    output = execute <<-SQL.squish
      SET LOCAL statement_timeout = 0;

      DELETE FROM schedule_histories
      WHERE NOT EXISTS (
          SELECT 1
          FROM thing_histories
          WHERE thing_histories.id = schedule_histories.thing_history_id
        );
    SQL

    puts "schedules -> things (#{output.count})" # rubocop:disable Rails/Output

    validate_foreign_key :schedule_histories, :thing_histories, column: :thing_history_id

    output = execute <<-SQL.squish
      SET LOCAL statement_timeout = 0;

      DELETE FROM thing_duplicates
      WHERE NOT EXISTS (
          SELECT 1
          FROM things
          WHERE things.id = thing_duplicates.thing_id
        );
    SQL

    puts "thing_duplicates(thing_id) -> things (#{output.count})" # rubocop:disable Rails/Output

    validate_foreign_key :thing_duplicates, :things, column: :thing_id

    output = execute <<-SQL.squish
      SET LOCAL statement_timeout = 0;

      DELETE FROM thing_duplicates
      WHERE NOT EXISTS (
          SELECT 1
          FROM things
          WHERE things.id = thing_duplicates.thing_duplicate_id
        );
    SQL

    puts "thing_duplicates(thing_duplicate_id) -> things (#{output.count})" # rubocop:disable Rails/Output

    validate_foreign_key :thing_duplicates, :things, column: :thing_duplicate_id

    output = execute <<-SQL.squish
      SET LOCAL statement_timeout = 0;

      DELETE FROM watch_list_data_hashes
      WHERE NOT EXISTS (
          SELECT 1
          FROM things
          WHERE things.id = watch_list_data_hashes.thing_id
        );
    SQL

    puts "watch_list_data_hashes(thing_id) -> things (#{output.count})" # rubocop:disable Rails/Output

    validate_foreign_key :watch_list_data_hashes, :things, column: :thing_id

    output = execute <<-SQL.squish
      SET LOCAL statement_timeout = 0;

      DELETE FROM thing_translations
      WHERE NOT EXISTS (
          SELECT 1
          FROM things
          WHERE things.id = thing_translations.thing_id
        );
    SQL

    puts "thing_translations(thing_id) -> things (#{output.count})" # rubocop:disable Rails/Output

    validate_foreign_key :thing_translations, :things, column: :thing_id

    output = execute <<-SQL.squish
      SET LOCAL statement_timeout = 0;

      DELETE FROM thing_history_translations
      WHERE NOT EXISTS (
          SELECT 1
          FROM thing_histories
          WHERE thing_histories.id = thing_history_translations.thing_history_id
        );
    SQL

    puts "thing_history_translations(thing_id) -> thing_histories (#{output.count})" # rubocop:disable Rails/Output

    validate_foreign_key :thing_history_translations, :thing_histories, column: :thing_history_id

    output = execute <<-SQL.squish
      SET LOCAL statement_timeout = 0;

      DELETE FROM subscriptions
      WHERE NOT EXISTS (
          SELECT 1
          FROM users
          WHERE users.id = subscriptions.user_id
        );
    SQL

    puts "subscriptions(thing_id) -> users (#{output.count})" # rubocop:disable Rails/Output

    validate_foreign_key :subscriptions, :users, column: :user_id

    output = execute <<-SQL.squish
      SET LOCAL statement_timeout = 0;

      DELETE FROM data_links
      WHERE NOT EXISTS (
          SELECT 1
          FROM users
          WHERE users.id = data_links.creator_id
        );
    SQL

    puts "data_links(creator_id) -> users (#{output.count})" # rubocop:disable Rails/Output

    validate_foreign_key :data_links, :users, column: :creator_id

    output = execute <<-SQL.squish
      SET LOCAL statement_timeout = 0;

      DELETE FROM data_links
      WHERE NOT EXISTS (
          SELECT 1
          FROM users
          WHERE users.id = data_links.receiver_id
        );
    SQL

    puts "data_links(receiver_id) -> users (#{output.count})" # rubocop:disable Rails/Output

    validate_foreign_key :data_links, :users, column: :receiver_id

    output = execute <<-SQL.squish
      SET LOCAL statement_timeout = 0;

      UPDATE activities
      SET user_id = NULL
      WHERE activities.user_id IS NOT NULL
      AND NOT EXISTS (
          SELECT 1
          FROM users
          WHERE users.id = activities.user_id
        );
    SQL

    puts "activities(user_id) -> users (#{output.count})" # rubocop:disable Rails/Output

    validate_foreign_key :activities, :users, column: :user_id

    output = execute <<-SQL.squish
      SET LOCAL statement_timeout = 0;

      DELETE FROM content_contents
      WHERE NOT EXISTS (
          SELECT 1
          FROM things
          WHERE things.id = content_contents.content_a_id
        );
    SQL

    puts "content_contents(content_a_id) -> things (#{output.count})" # rubocop:disable Rails/Output

    validate_foreign_key :content_contents, :things, column: :content_a_id

    output = execute <<-SQL.squish
      SET LOCAL statement_timeout = 0;

      DELETE FROM content_contents
      WHERE NOT EXISTS (
          SELECT 1
          FROM things
          WHERE things.id = content_contents.content_b_id
        );
    SQL

    puts "content_contents(content_b_id) -> things (#{output.count})" # rubocop:disable Rails/Output

    validate_foreign_key :content_contents, :things, column: :content_b_id

    DataCycleCore::RunTaskJob.perform_later('db:maintenance:vacuum')
  end

  def down
  end
end
