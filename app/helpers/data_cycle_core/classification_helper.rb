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
      safe_join([classification_alias.full_path, classification_alias.description.presence].compact, '<br><br>')
    end

    def expected_classification_alias(c)
      c.is_a?(DataCycleCore::Classification) ? c&.primary_classification_alias : c
    end

    def expected_value_id(c, expected_type)
      if c.is_a?(expected_type) then c&.id
      elsif expected_type == DataCycleCore::Classification then c&.primary_classification&.id
      else c&.primary_classification_alias&.id
      end
    end

    def classification_alias_filter_items(tree_label, order_by = nil)
      return DataCycleCore::ClassificationAlias.none if tree_label.blank?

      DataCycleCore::ClassificationAlias
        .for_tree(tree_label)
        .includes(
          :primary_classification, :classification_alias_path, sub_classification_alias: [
            :primary_classification, :classification_alias_path, sub_classification_alias: [
              :primary_classification, :classification_alias_path, :sub_classification_alias
            ]
          ]
        )
        .order(order_by)
    end

    def async_classification_select_options(value, expected_type = DataCycleCore::ClassificationAlias)
      return options_for_select([]) if value.blank?

      options_for_select(
        value.map do |c|
          [
            expected_classification_alias(c)&.internal_name,
            expected_value_id(c, expected_type),
            {
              title: [
                expected_classification_alias(c)&.full_path,
                expected_classification_alias(c)&.description
              ].reject(&:blank?).join("\n\n")
            }
          ]
        end,
        value.pluck(:id)
      )
    end

    def simple_classification_select_options(value, classification_items, expected_type = DataCycleCore::ClassificationAlias)
      options_for_select(
        classification_items
          &.where&.not(internal_name: DataCycleCore.excluded_filter_classifications)
          &.map do |c|
          [
            expected_classification_alias(c)&.internal_name,
            expected_value_id(c, expected_type),
            {
              title: [
                expected_classification_alias(c)&.full_path,
                expected_classification_alias(c)&.description
              ].reject(&:blank?).join("\n\n"),
              data: {
                title: expected_classification_alias(c)&.full_path
              }
            }
          ]
        end,
        value&.pluck(:id)
      )
    end
  end
end
