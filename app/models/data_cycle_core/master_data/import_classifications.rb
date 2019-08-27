# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module ImportClassifications
      def self.import_all(_validation: true, classification_paths: nil)
        classification_paths ||= Array(DataCycleCore.default_template_paths).flatten.uniq.compact
        project_classification_path = DataCycleCore.template_path

        if classification_paths.blank? && project_classification_path.blank?
          puts '###### classifications not found'
          return
        end

        merged_data_trees = {}

        classification_paths.each do |classification_path|
          file = classification_path + 'classifications.yml'
          next unless File.exist?(file)
          tree_array = YAML.safe_load(File.open(file.to_s), [Symbol])
          tree_hash = iterate_array(tree_array)
          merged_data_trees = merge_trees(merged_data_trees, tree_hash)
        end

        if project_classification_path.present? && File.exist?(project_classification_path += 'classifications.yml')
          tree_array = YAML.safe_load(File.open(project_classification_path.to_s), [Symbol])
          tree_hash = iterate_array(tree_array)
          merged_data_trees = merge_trees(merged_data_trees, tree_hash, true)
        end

        return_data = iterate_tree_hash(merged_data_trees)
        check_features
        return_data
      end

      def self.merge_trees(merged_hash, tree, replace_keys = false)
        tree.each do |key, sub_tree|
          next if sub_tree.blank?
          old_hash = merged_hash.select { |k, _| k.split('|').first.squish == key.split('|').first.squish }
          old_value = merged_hash.delete(old_hash&.keys&.first)

          if replace_keys && key.exclude?('Inhaltstypen')
            merged_hash[key] = sub_tree
          else
            merged_hash[key] = old_value&.values&.first.present? ? merge_trees(old_value, sub_tree) : sub_tree
          end
        end
        merged_hash
      end

      def self.iterate_array(array)
        data = array.map { |item| item.is_a?(::String) ? { item => nil } : item }.reduce({}, :merge)
        data.map { |key, value|
          if value.blank? || value.is_a?(::String)
            { key => value }
          else
            { key => iterate_array(data[key]) }
          end
        }.reduce({}, :merge)
      end

      def self.iterate_tree_hash(trees_hash)
        trees_hash.each do |k, v|
          @label_id = get_label(k).id
          walk_tree_hash(v, nil)
        end
      end

      def self.walk_tree_hash(data_tree, parent)
        # data format> [$$]name[ | description]
        return nil if data_tree.blank?
        data_tree.each do |k, v|
          internal = false
          if k.starts_with?('$$') # '$$' prefix for interal classifications
            k = k[2..(k.length - 1)]
            internal = true
          end
          split_data = k.split('|').map(&:squish)
          name = split_data[0]
          description = split_data[1]
          current_id = save_data(name, parent, internal, description)

          walk_tree_hash(v, current_id) if v.is_a?(Hash)
        end
      end

      def self.save_data(data, parent, internal, description)
        find_alias = DataCycleCore::ClassificationAlias
          .joins(:classification_tree)
          .find_by(
            classification_aliases: { name: data },
            classification_trees: { classification_tree_label_id: @label_id, parent_classification_alias_id: parent }
          )

        puts "WARNING: Duplicate ClassificationAlias '#{data}' found, check classification.yml to fix this" if DataCycleCore::ClassificationAlias
          .joins(:classification_tree)
          .where(
            classification_aliases: { name: data },
            classification_trees: { classification_tree_label_id: @label_id }
          ).where.not(classification_trees: { parent_classification_alias_id: parent }).exists?

        if find_alias.present?
          updated_data = find_alias
          update_hash = { seen_at: Time.zone.now, internal: internal, description: description || updated_data.description }
          updated_data.update(update_hash)
        else
          # new Alias, create respective tree-entry
          updated_data = DataCycleCore::ClassificationAlias.create(name: data, internal: internal, seen_at: Time.zone.now, description: description)
          DataCycleCore::ClassificationTree.find_or_create_by(
            classification_alias_id: updated_data.id,
            parent_classification_alias_id: parent,
            classification_tree_label_id: @label_id
          ) do |tree_entry|
            tree_entry.seen_at = Time.zone.now
          end
        end
        upsert_classification(data, updated_data.id, description)
        updated_data.id
      end

      def self.get_label(label)
        split_data = label.split('|').map(&:squish)
        label = split_data[0]
        visibility = split_data[1] == 'all' ? DataCycleCore.classification_visibilities.except('show_more') : (split_data[1]&.split(',')&.map(&:squish) || [])

        DataCycleCore::ClassificationTreeLabel.find_or_create_by(name: label) do |label_data|
          label_data.seen_at = Time.zone.now
          label_data.visibility = visibility
        end
      end

      def self.upsert_classification(data, classification_alias_id, description)
        find_classification = DataCycleCore::Classification
          .joins(classification_groups: [:classification_alias])
          .where(classification_aliases: { id: classification_alias_id })
        if find_classification.count < 1
          classification = DataCycleCore::Classification.create(name: data, external_source_id: nil, description: description) do |item|
            item.seen_at = Time.zone.now
          end
          DataCycleCore::ClassificationGroup.create(classification_id: classification.id, classification_alias_id: classification_alias_id, external_source_id: nil) do |group|
            group.seen_at = Time.zone.now
          end
        else
          classification = find_classification.first
          update_hash = { name: data, seen_at: Time.zone.now, description: description || classification.description }
          classification.update(update_hash)
        end
      end

      def self.updated_classification_statistics(timestamp = Time.zone.now)
        classifications = {}
        DataCycleCore::ClassificationAlias.for_tree('Inhaltstypen').where('classification_aliases.seen_at < ?', timestamp.utc.to_s(:long_usec))
          .where(internal: true).where.not(seen_at: nil).find_each do |classification|
            classifications[classification.internal_name] = {
              seen_at: classification.seen_at,
              count: classification.linked_contents.count
            }
          end
        classifications
          .to_a
          .sort_by { |item| item[1][:seen_at] }
          .reduce({}) { |aggregate, item| aggregate.merge({ item[0] => item[1] }) }
      end

      def self.check_features
        return unless DataCycleCore::Feature::AutoTagging.enabled?

        tree_name = DataCycleCore.features.dig(:auto_tagging, :tree_label) || 'Cloud Vision - Tags'
        tree_label = DataCycleCore::ClassificationTreeLabel.find_by(name: tree_name, external_source_id: nil)
        external_source_name = DataCycleCore.features.dig(:auto_tagging, :external_source) || 'Google Cloud Vision'
        return if tree_label.blank? || external_source_name.blank?

        external_source_id = DataCycleCore::ExternalSource.find_by(name: external_source_name)&.id
        return if external_source_id.blank?

        tree_label.external_source_id = external_source_id
        tree_label.save
        DataCycleCore::ClassificationAlias.for_tree(tree_name).update_all(external_source_id: external_source_id) # rubocop:disable Rails/SkipsModelValidations
      end
    end
  end
end
