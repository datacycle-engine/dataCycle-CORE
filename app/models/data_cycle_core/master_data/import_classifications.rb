module DataCycleCore
  module MasterData
    class ImportClassifications
      def import(filename)
        begin
          data_trees = YAML.load(File.open(filename))
          iterate_tree_array(data_trees)
        rescue Exception => e
          puts "could not access the file: #{filename}"
          puts e.message
          puts e.backtrace
        end
      end

      def iterate_tree_array(trees_array)
        trees_array.each do |item|
          @label_id = get_label(item.keys.first).id
          walk_tree(item[item.keys.first], nil)
        end
      end

      def walk_tree(data_tree, parent)
        return nil if data_tree.blank?
        data_tree.each do |data|
          internal = false
          if data.is_a?(String)
            if data.starts_with?('$$')            # '$$' prefix for interal classifications
              data = data[2..(data.length - 1)]
              internal = true
            end
            save_data(data, parent, internal)
          elsif data.is_a?(Hash)
            parent_name = data.keys.first
            if data.keys.first.starts_with?('$$') # '$$' prefix for interal classifications
              parent_name = data.keys.first[2..(data.keys.first.length - 1)]
              internal = true
            end
            parent_id = save_data(parent_name, parent, internal)
            walk_tree(data[data.keys.first], parent_id)
          end
        end
      end

      def save_data(data, parent, internal)
        if parent.nil?
          find_alias = DataCycleCore::ClassificationAlias
            .joins(:classification_tree)
            .where("classification_trees.classification_tree_label_id = ?", @label_id)
            .where("classification_aliases.name = ?", data)
            .where("classification_trees.parent_classification_alias_id is NULL")
        else
          find_alias = DataCycleCore::ClassificationAlias
            .joins(:classification_tree)
            .where("classification_trees.classification_tree_label_id = ?", @label_id)
            .where("classification_aliases.name = ?", data)
            .where("classification_trees.parent_classification_alias_id = ?", parent)
        end
        if find_alias.count.positive?
          updated_data = find_alias.first
          updated_data.seen_at = Time.zone.now
          updated_data.internal = internal
          updated_data.save
        else
          # new Alias, create respective tree-entry
          updated_data = DataCycleCore::ClassificationAlias.create(name: data, internal: internal, seen_at: Time.zone.now)
          DataCycleCore::ClassificationTree.find_or_create_by(
            classification_alias_id: updated_data.id,
            parent_classification_alias_id: parent,
            classification_tree_label_id: @label_id
          ) do |tree_entry|
            tree_entry.seen_at = Time.zone.now
          end
        end
        upsert_classification(data, updated_data.id)
        updated_data.id
      end

      def get_label(label)
        DataCycleCore::ClassificationTreeLabel.find_or_create_by(name: label, external_source_id: nil) do |label_data|
          label_data.seen_at = Time.zone.now
        end
      end

      def upsert_classification(data, classification_alias_id)
        find_classification = DataCycleCore::Classification
          .joins(classification_groups: [:classification_alias])
          .where("classification_aliases.id = ? ", classification_alias_id)
          .where("classification_aliases.name = ? ", data)
        if find_classification.count < 1
          classification = DataCycleCore::Classification.create(name: data, external_source_id: nil) do |item|
            item.seen_at = Time.zone.now
          end
          DataCycleCore::ClassificationGroup.create(classification_id: classification.id, classification_alias_id: classification_alias_id, external_source_id: nil) do |group|
            group.seen_at = Time.zone.now
          end
        else
          classification = find_classification.first
          classification.name = data
          classification.seen_at = Time.zone.now
          classification.save
        end
      end
    end
  end
end
