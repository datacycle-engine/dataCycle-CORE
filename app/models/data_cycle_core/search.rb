module DataCycleCore
  class Search < ApplicationRecord
    class ClassificationRelation < ApplicationRecord
      self.table_name = 'classification_contents'

      belongs_to :classification
    end

    belongs_to :content_data, polymorphic: true

    has_many :classification_relations, primary_key: :content_data_id, foreign_key: :content_data_id
    has_many :classifications, through: :classification_relations
    has_many :classification_groups, through: :classifications
    has_many :classification_aliases, through: :classification_groups
  end
end
