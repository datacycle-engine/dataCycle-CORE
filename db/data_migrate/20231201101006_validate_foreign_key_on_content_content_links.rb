# frozen_string_literal: true

class ValidateForeignKeyOnContentContentLinks < ActiveRecord::Migration[6.1]
  # uncomment the following line to disable transactions
  disable_ddl_transaction!

  def up
    output = execute <<-SQL.squish
      DELETE FROM content_content_links
      WHERE NOT EXISTS (
          SELECT 1
          FROM content_contents
          WHERE content_contents.id = content_content_links.content_content_id
        );
    SQL

    puts "content_content_links -> content_contents (#{output.count})" # rubocop:disable Rails/Output

    validate_foreign_key :content_content_links, :content_contents

    execute <<-SQL.squish
      SELECT generate_content_content_links(ARRAY_AGG(id)) FROM content_contents;
    SQL

    execute('VACUUM (FULL, ANALYZE) content_content_links;')
    execute('VACUUM (ANALYZE) content_content_links;')
  end

  def down
  end
end
