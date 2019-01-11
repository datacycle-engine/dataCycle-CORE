# frozen_string_literal: true

require 'csv'

module DataCycleCore
  class ClassificationTreeLabel < ApplicationRecord
    class Statistics < ApplicationRecord
      self.table_name = 'classification_tree_label_statistics'

      belongs_to :classification_tree_label, foreign_key: 'id', inverse_of: :statistics

      def readonly?
        true
      end
    end

    acts_as_paranoid

    belongs_to :external_source

    has_many :classification_trees, dependent: :destroy
    has_many :classification_aliases, through: :classification_trees, source: :sub_classification_alias do
      def roots
        joins(:classification_tree).where(classification_trees: { parent_classification_alias_id: nil })
      end
    end
    has_one :statistics, class_name: 'Statistics', foreign_key: 'id', inverse_of: :classification_tree_label # rubocop:disable Rails/HasManyOrHasOneDependent

    def create_classification_alias(*classification_attributes)
      parent_classification_alias = nil
      classification_attributes.map { |attributes|
        if attributes.is_a?(String)
          {
            name: attributes
          }
        else
          attributes
        end
      }.each do |attributes|
        if parent_classification_alias
          classification_alias = parent_classification_alias
            .sub_classification_alias
            .where(name: attributes[:name], external_source: attributes[:external_source])
            .first_or_initialize
        else
          classification_alias = classification_aliases.roots
            .where(name: attributes[:name], external_source: attributes[:external_source])
            .first_or_initialize
        end

        if classification_alias.new_record?
          classification_alias.save!

          classification = Classification.create!(name: attributes[:name],
                                                  external_source: attributes[:external_source],
                                                  external_key: attributes[:external_key])

          ClassificationGroup.create!(classification: classification,
                                      classification_alias: classification_alias)

          ClassificationTree.create!(classification_tree_label: self,
                                     parent_classification_alias: parent_classification_alias,
                                     sub_classification_alias: classification_alias)
        end

        parent_classification_alias = classification_alias
      end

      parent_classification_alias
    end

    def to_csv(include_contents: false)
      CSV.generate do |csv|
        csv << [name]
        classification_aliases.sort_by(&:full_path).each do |classification_alias|
          csv << Array.new(classification_alias.ancestors.count) + [classification_alias.name]

          if include_contents
            classification_alias.linked_contents.each do |content_relation|
              content_relation.content_data.translations.each do |content_translation|
                row = Array.new(classification_alias.ancestors.count + 1)
                row += [
                  content_relation.content_data.template_name,
                  content_translation.locale,
                  content_translation.name
                ]
                csv << row
              end
            end
          end
        end
      end
    end

    def ancestors
      []
    end
  end
end
