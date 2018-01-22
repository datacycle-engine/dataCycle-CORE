require 'csv'

module DataCycleCore
  class ClassificationTreeLabel < ApplicationRecord
    acts_as_paranoid

    belongs_to :external_source

    has_many :classification_trees, dependent: :destroy
    has_many :classification_aliases, through: :classification_trees, source: :sub_classification_alias

    def to_csv
      CSV.generate do |csv|
        csv << [self.name]
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
