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
      data_tree.each do |data|
        if data.kind_of?(String)
          save_data(data, parent)
        elsif data.kind_of?(Hash)
          parent_id = save_data(data.keys.first, parent)
          walk_tree(data[data.keys.first], parent_id)
        end
      end
    end

    def save_data(data, parent)
      if parent.nil?
        find_alias = DataCycleCore::ClassificationAlias
          .joins(:classification_trees)
          .where("classification_trees.classification_tree_label_id = ?", @label_id)
          .where("classification_aliases.name = ?", data)
          .where("classification_trees.parent_classification_alias_id is NULL")
      else
        find_alias = DataCycleCore::ClassificationAlias
          .joins(:classification_trees)
          .where("classification_trees.classification_tree_label_id = ?", @label_id)
          .where("classification_aliases.name = ?", data)
          .where("classification_trees.parent_classification_alias_id = ?", parent)
      end
      if find_alias.count > 0
        updated_data = find_alias.first
        updated_data.set_data({seen_at: Time.zone.now}).save
      else
        # new Alias, create respective tree-entry
        updated_data = DataCycleCore::ClassificationAlias.create(name: data, seen_at: Time.zone.now)
        DataCycleCore::ClassificationTree.find_or_create_by(
          classification_alias_id: updated_data.id,
          parent_classification_alias_id: parent,
          classification_tree_label_id: @label_id) do |tree_entry|
            tree_entry.seen_at = Time.zone.now
        end
      end
      updated_data.id
    end

    def get_label(label)
      DataCycleCore::ClassificationTreeLabel.find_or_create_by(name: label, external_source_id: nil) do |label_data|
        label_data.seen_at = Time.zone.now
      end
    end

  end
end
