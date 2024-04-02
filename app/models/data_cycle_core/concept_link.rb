# frozen_string_literal: true

module DataCycleCore
  class ConceptLink < ApplicationRecord
    belongs_to :parent, class_name: 'Concept'
    belongs_to :child, class_name: 'Concept'

    # keep readonly until reverse triggers are defined and working
    def readonly?
      true
    end

    def self.create(attributes = nil, &)
      if attributes.is_a?(Array)
        attributes.collect { |attr| create(attr, &) }
      else
        if attributes[:link_type] == 'broader'
          attributes[:parent_classification_alias_id] = attributes.delete(:parent_id) if attributes.key?(:parent_id)
          attributes[:parent_classification_alias] = attributes.delete(:parent)&.classification_alias if attributes.key?(:parent)
          attributes[:classification_alias_id] = attributes.delete(:child_id) if attributes.key?(:child_id)
          attributes[:sub_classification_alias] = attributes.delete(:child)&.classification_alias if attributes.key?(:child)
          attributes[:classification_tree_label] = attributes.key?(:classification_alias) ? attributes[:classification_alias].classification_tree_label : ClassificationAlias.find_by(id: attributes[:classification_alias_id])&.classification_tree_label

          object = ClassificationTree.create(attributes.slice(:parent_classification_alias_id, :parent_classification_alias, :classification_alias_id, :sub_classification_alias, :classification_tree_label), &)
        elsif attributes[:link_type] == 'related'
          attributes[:classification_alias_id] = attributes.delete(:parent_id) if attributes.key?(:parent_id)
          attributes[:classification_alias] = attributes.delete(:parent)&.classification_alias if attributes.key?(:parent)
          attributes[:classification_id] = Concept.find_by(id: attributes.delete(:child_id))&.classification_id if attributes.key?(:child_id)
          attributes[:classification] = attributes.delete(:child)&.classification if attributes.key?(:child)

          object = ClassificationGroup.create(attributes.slice(:classification_alias_id, :classification_alias, :classification_id, :classification), &)
        end

        object&.valid? ? find_by(id: object.id) : object
      end
    end

    def self.create!(attributes = nil, &)
      if attributes.is_a?(Array)
        attributes.collect { |attr| create!(attr, &) }
      else
        if attributes[:linkt_type] == 'broader'
          attributes[:parent_classification_alias_id] = attributes.delete(:parent_id) if attributes.key?(:parent_id)
          attributes[:parent_classification_alias] = attributes.delete(:parent)&.classification_alias if attributes.key?(:parent)
          attributes[:classification_alias_id] = attributes.delete(:child_id) if attributes.key?(:child_id)
          attributes[:classification_alias] = attributes.delete(:child)&.classification_alias if attributes.key?(:child)
          attributes[:classification_tree_label] = attributes.key?(:classification_alias) ? attributes[:classification_alias].classification_tree_label : ClassificationAlias.find_by(id: attributes[:classification_alias_id])&.classification_tree_label

          object = ClassificationTree.create!(attributes.slice(:parent_classification_alias_id, :parent_classification_alias, :classification_alias_id, :classification_alias, :classification_tree_label), &)
        elsif attributes[:linkt_type] == 'related'
          attributes[:classification_alias_id] = attributes.delete(:parent_id) if attributes.key?(:parent_id)
          attributes[:classification_alias] = attributes.delete(:parent)&.classification_alias if attributes.key?(:parent)
          attributes[:classification_id] = Concept.find_by(id: attributes.delete(:child_id))&.classification_id if attributes.key?(:child_id)
          attributes[:classification] = attributes.delete(:child)&.classification if attributes.key?(:child)

          object = ClassificationGroup.create!(attributes, &)
        end

        find(object.id)
      end
    end
  end
end
