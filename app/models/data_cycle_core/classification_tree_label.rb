require 'csv'

module DataCycleCore
  class ClassificationTreeLabel < ApplicationRecord
    acts_as_paranoid

    belongs_to :external_source

    has_many :classification_trees, dependent: :destroy
    has_many :classification_aliases, through: :classification_trees, source: :sub_classification_alias do
      def roots
        joins(:classification_tree).where(classification_trees: { parent_classification_alias_id: nil })
      end
    end

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
        classification_alias = if parent_classification_alias
                                 parent_classification_alias
                                   .sub_classification_alias
                                   .where(name: attributes[:name],
                                          external_source: attributes[:external_source])
                                   .first_or_initialize
                               else
                                 classification_aliases.roots
                                   .where(name: attributes[:name],
                                          external_source: attributes[:external_source])
                                   .first_or_initialize
                               end

        if classification_alias.new_record?
          classification_alias.save!

          classification = Classification.create!(name: attributes[:name],
                                                  external_source: attributes[:external_source],
                                                  external_key: attributes[:external_key])

          classification_group = ClassificationGroup.create!(classification: classification,
                                                             classification_alias: classification_alias)

          classification_tree = ClassificationTree.create!(classification_tree_label: self,
                                                           parent_classification_alias: parent_classification_alias,
                                                           sub_classification_alias: classification_alias)
        end

        parent_classification_alias = classification_alias
      end

      parent_classification_alias
    end

    def to_csv
      CSV.generate do |csv|
        csv << [name]
        classification_aliases.each do |classification_alias|
          csv << Array.new(classification_alias.ancestors.count) + [classification_alias.name]
        end
      end
    end

    def ancestors
      []
    end
  end
end
