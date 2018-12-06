# frozen_string_literal: true

delete_classifications = <<-EOS
  DELETE FROM classifications;
  DELETE FROM classification_groups;
  DELETE FROM classification_aliases;
  DELETE FROM classification_trees;
  DELETE FROM classification_tree_labels;
EOS

delete_secondary_data = <<-EOS
  DELETE FROM watch_list_data_hashes;
  DELETE FROM watch_lists;
  DELETE FROM subscriptions;
  DELETE FROM data_links;
EOS

delete_contents = <<-EOS
  DELETE FROM creative_works;
  DELETE FROM creative_work_translations;
  DELETE FROM events;
  DELETE FROM event_translations;
  DELETE FROM persons;
  DELETE FROM person_translations;
  DELETE FROM organizations;
  DELETE FROM organization_translations;
  DELETE FROM places;
  DELETE FROM place_translations;

  DELETE FROM content_contents;

  DELETE FROM classification_contents;
  DELETE FROM searches;
EOS

delete_assets = <<-EOS
  DELETE FROM assets;
  DELETE FROM asset_contents;
EOS

delete_content_histories = <<-EOS
  DELETE FROM creative_work_histories;
  DELETE FROM creative_work_history_translations;
  DELETE FROM event_histories;
  DELETE FROM event_history_translations;
  DELETE FROM person_histories;
  DELETE FROM person_history_translations;
  DELETE FROM organization_histories;
  DELETE FROM organization_history_translations;
  DELETE FROM place_histories;
  DELETE FROM place_history_translations;

  DELETE FROM content_content_histories;

  DELETE FROM classification_content_histories;
EOS

delete_soft_deleted_classifications = <<-EOS
  DELETE FROM classifications WHERE deleted_at IS NOT NULL;
  DELETE FROM classification_groups WHERE deleted_at IS NOT NULL;
  DELETE FROM classification_aliases WHERE deleted_at IS NOT NULL;
  DELETE FROM classification_trees WHERE deleted_at IS NOT NULL;
  DELETE FROM classification_tree_labels WHERE deleted_at IS NOT NULL;
EOS

namespace :data_cycle_core do
  namespace :clear do
    desc 'Remove all data except for configuration data like users'
    task all: :environment do
      ActiveRecord::Base.connection.execute(delete_classifications)
      ActiveRecord::Base.connection.execute(delete_secondary_data)
      ActiveRecord::Base.connection.execute(delete_contents)
      ActiveRecord::Base.connection.execute(delete_content_histories)
      ActiveRecord::Base.connection.execute(delete_assets)
    end

    desc 'Remove all contents related data like creative works and places (does not remove classifications)'
    task contents: :environment do
      ActiveRecord::Base.connection.execute(delete_secondary_data)
      ActiveRecord::Base.connection.execute(delete_contents)
      ActiveRecord::Base.connection.execute(delete_content_histories)
    end

    desc 'Remove all assets and asset relations'
    task assets: :environment do
      ActiveRecord::Base.connection.execute(delete_assets)
    end

    desc 'Remove the history of all content data'
    task history: :environment do
      ActiveRecord::Base.connection.execute(delete_content_histories)
    end

    desc 'Remove all soft-deleted classification data (paranoid)'
    task classifications: :environment do
      ActiveRecord::Base.connection.execute(delete_soft_deleted_classifications)
    end
  end
end
