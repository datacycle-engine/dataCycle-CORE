# frozen_string_literal: true

namespace :data_cycle_core do
  namespace :classifications do
    desc 'perform consistency checks on the db'
    task ensure_consistency: :environment do
      partially_deleted_entities = ActiveRecord::Base.connection.execute <<-SQL.squish
        SELECT
          primary_classification_groups.id "classification_group_id",
          classification_aliases.id "classification_alias_id",
          classifications.id "classification_id"
        FROM primary_classification_groups
          JOIN classifications ON classifications.id = classification_id
          JOIN classification_aliases ON classification_aliases.id = classification_alias_id
        WHERE NOT (primary_classification_groups.deleted_at IS NULL AND
                   classifications.deleted_at IS NULL AND
                   classification_aliases.deleted_at IS NULL)
          AND NOT (primary_classification_groups.deleted_at IS NOT NULL AND
                   classifications.deleted_at IS NOT NULL AND
                   classification_aliases.deleted_at IS NOT NULL);
      SQL

      inconsistent_names = ActiveRecord::Base.connection.execute <<-SQL.squish
        SELECT
          classification_aliases.id "classification_alias_id",
          classifications.id "classification_id"
        FROM primary_classification_groups
          JOIN classifications ON classifications.id = classification_id
          JOIN classification_aliases ON classification_aliases.id = classification_alias_id
        WHERE classifications.name <> classification_aliases.name;
      SQL

      unless partially_deleted_entities.none? && inconsistent_names.none?
        progressbar = ProgressBar.create(total: partially_deleted_entities.count + inconsistent_names.count)

        partially_deleted_entities.each do |row|
          DataCycleCore::Classification.with_deleted.find(row['classification_id']).update(deleted_at: nil)
          DataCycleCore::ClassificationAlias.with_deleted.find(row['classification_alias_id']).update(deleted_at: nil)
          DataCycleCore::ClassificationGroup.with_deleted.find(row['classification_group_id']).update(deleted_at: nil)

          progressbar.increment
        end

        inconsistent_names.each do |row|
          classification = DataCycleCore::Classification.with_deleted.find(row['classification_id'])
          classification_alias = DataCycleCore::ClassificationAlias.with_deleted.find(row['classification_alias_id'])

          if classification.name.blank? && classification_alias.name.present?
            classification.update!(name: classification_alias.name)
          elsif classification.name.present? && classification_alias.name.blank?
            classification_alias.update!(name: classification.name)
          elsif classification.updated_at < classification_alias.updated_at
            classification.update!(name: classification_alias.name)
          else
            classification_alias.update!(name: classification.name)
          end

          progressbar.increment
        end
      end
    end
  end
end
