# frozen_string_literal: true

class CleanupForForeignKeysAndUniqueContraintsForAssetContents < ActiveRecord::Migration[6.1]
  def up
    content_data_id_nil = execute <<-SQL.squish
      DELETE FROM asset_contents
      WHERE asset_contents.content_data_id IS NULL;
    SQL

    asset_id_nil = execute <<-SQL.squish
      DELETE FROM asset_contents
      WHERE asset_contents.asset_id IS NULL;
    SQL

    asset_missing = execute <<-SQL.squish
      DELETE FROM asset_contents
      WHERE NOT EXISTS (
          SELECT 1
          FROM assets
          WHERE assets.id = asset_contents.asset_id
        );
    SQL

    content_missing = execute <<-SQL.squish
      DELETE FROM asset_contents
      WHERE asset_contents.content_data_type = 'DataCycleCore::Thing'
      AND NOT EXISTS (
          SELECT 1
          FROM things
          WHERE things.id = asset_contents.content_data_id
        );
    SQL

    duplicate_assets_for_content = execute <<-SQL.squish
      WITH to_delete AS (
        SELECT ac.id,
          row_number() over w AS row_num
        FROM asset_contents ac
        WHERE ac.content_data_type = 'DataCycleCore::Thing'
        window w AS (
            PARTITION by ac.content_data_id,
            ac.relation
            ORDER BY ac.created_at DESC
          )
      )
      DELETE FROM asset_contents USING to_delete
      WHERE asset_contents.id = to_delete.id
        AND to_delete.row_num > 1;
    SQL

    subquery = <<-SQL.squish
      WITH to_delete AS (
        SELECT ac.id,
          row_number() over w AS row_num
        FROM asset_contents ac
          LEFT OUTER JOIN things ON things.id = ac.content_data_id window w AS (
            PARTITION by ac.asset_id
            ORDER BY ac.created_at DESC
          )
      )
      SELECT to_delete.id
      FROM to_delete
      WHERE to_delete.row_num > 1
    SQL

    to_duplicate = DataCycleCore::AssetContent.where("id IN (#{subquery})")
    assets_with_multiple_contents = to_duplicate.size

    to_duplicate.includes(:asset).find_each do |asset_content|
      asset = asset_content.asset.duplicate
      next asset_content.destroy if asset.nil?

      asset_content.update_columns(asset_id: asset.id)
    rescue StandardError
      puts "asset missing for asset_content with id: #{asset_content.id}, deleting asset_content" # rubocop:disable Rails/Output
      asset_content.delete
    end

    # rubocop:disable Rails/Output
    puts '##############################################################'
    puts '###################### Gelöschte asset_contents ##############'
    puts "################### content_data_id IS NULL => #{content_data_id_nil.cmd_tuples.to_i.to_s.rjust(6)} ########"
    puts "########################## asset_id IS NULL => #{asset_id_nil.cmd_tuples.to_i.to_s.rjust(6)} ########"
    puts "###################### asset does not exist => #{asset_missing.cmd_tuples.to_i.to_s.rjust(6)} ########"
    puts "#################### content does not exist => #{content_missing.cmd_tuples.to_i.to_s.rjust(6)} ########"
    puts "############## content has duplicate assets => #{duplicate_assets_for_content.cmd_tuples.to_i.to_s.rjust(6)} ########"
    puts '###################### Duplizierte assets ####################'
    puts "######## asset belongs to multiple contents => #{assets_with_multiple_contents.to_i.to_s.rjust(6)} ########"
    puts '##############################################################'
    # rubocop:enable Rails/Output
  end

  def down
  end
end
