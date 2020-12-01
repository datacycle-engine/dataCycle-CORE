# frozen_string_literal: true

module DataCycleCore
  module ClassificationHelper
    # TODO: refactor
    def get_classifications_for_name(name)
      return if name.blank?

      DataCycleCore::ClassificationTreeLabel
        .includes(classification_trees: [:classification_tree_label, :sub_classification_alias])
        .find_by(name: name)
    end

    # TODO: refactor
    def get_classifications_for_id(uids, tree_label = nil)
      unless uids.nil?
        if !tree_label.nil?
          allowed_classifications = get_classifications_for_name(tree_label)
            .classification_trees
            .map { |classification| classification.sub_classification_alias.id }
          allowed_uids = uids.select { |uid| allowed_classifications.include?(uid) }
          @selected_classifications = DataCycleCore::ClassificationAlias.find(allowed_uids)
        else
          @selected_classifications = DataCycleCore::ClassificationAlias.find(uids)
        end
      end
    rescue StandardError
      logger.warn("cannot find classifications for the following ids: #{(uids || []).join(', ')}")
      nil
    end

    # def get_selected_values_for_classification(options, value)
    #   return nil if value.nil?
    #
    #   # TODO: make this more fancy
    #   @selected_values = []
    #   Array(value).each do |v|
    #     options.each do |o|
    #       @selected_values.push(o) if o[1] == v
    #     end
    #   end
    #
    #   @selected_values
    # end

    # def get_custom_select_values(classification_alias)
    #   walk_classification_tree(classification_alias)
    # end

    # def life_cycle_items
    #   if DataCycleCore.features.dig(:life_cycle)
    #     Rails.cache.fetch("life_cycle_#{DataCycleCore.features.dig(:life_cycle, :ordered)&.join(' ')&.parameterize(separator: '_')}", expires_in: 10.minutes) do
    #       DataCycleCore::Classification.where(name: DataCycleCore.features.dig(:life_cycle, :ordered)).sort_by { |c| DataCycleCore.features.dig(:life_cycle, :ordered)&.index c.name }.map { |c| [c.name, { id: c.id, alias: c.primary_classification_alias }] }.to_h
    #     end
    #   else
    #     {}
    #   end
    # end

    # def walk_classification_tree(classification_alias)
    #   classification_tree = []
    #   return if classification_alias.nil?
    #   classification_alias.each do |value|
    #     classification_tree.push([value.name, value.classifications.ids.first])
    #     classification_tree.push(walk_classification_tree(value.sub_classification_alias).flatten)
    #   end
    #   classification_tree
    # end

    def classification_tree_label_has_children?(treelabel)
      DataCycleCore::Classification
        .includes(:classification_groups, :classification_aliases)
        .joins(classification_aliases: [classification_tree: [:classification_tree_label]])
        .where('classification_tree_labels.name = ?', treelabel).count.positive?
    end

    def classification_tooltip(classification_alias)
      "#{classification_alias.full_path}#{"\n\n#{strip_tags(classification_alias.description)}" if classification_alias.description.present?}".html_safe # rubocop:disable Rails/OutputSafety
    end

    def advanced_filter_classification_items(tree_label)
      return [] if tree_label.blank?

      DataCycleCore::ClassificationTreeLabel
        .find_by(name: tree_label)
        &.classification_trees
        &.includes(
          :parent_classification_alias, sub_classification_alias: [
            :classifications, :classification_alias_path, sub_classification_alias: [
              :classifications, :classification_alias_path, sub_classification_alias: [
                :classifications, :classification_alias_path, :sub_classification_alias
              ]
            ]
          ]
        ) || []
    end

    def async_classification_select_options(value, selected_classification_aliases)
      return nil if value.blank?

      options_for_select(
        value.map do |c|
          [
            selected_classification_aliases[c].try(:internal_name),
            c,
            {
              title: [
                selected_classification_aliases[c].full_path,
                selected_classification_aliases[c].description
              ].reject(&:blank?).join("\n\n")
            }
          ]
        end, value
      )
    end

    def simple_classification_select_options(value, classification_items)
      options_for_select(
        classification_items
          &.select { |type| !DataCycleCore.excluded_filter_classifications.include?(type.sub_classification_alias.try(:internal_name)) }
          &.map do |c|
          [
            c.sub_classification_alias.try(:internal_name),
            c.sub_classification_alias.try(:id),
            {
              title: [
                c.sub_classification_alias.full_path,
                c.sub_classification_alias.description
              ].reject(&:blank?).join("\n\n"),
              data: {
                title: c.sub_classification_alias.full_path
              }
            }
          ]
        end,
        value
      )
    end
  end
end
