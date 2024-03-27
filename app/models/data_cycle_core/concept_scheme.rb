# frozen_string_literal: true

module DataCycleCore
  class ConceptScheme < ApplicationRecord
    validates :name, presence: true

    belongs_to :external_system

    has_many :concepts, dependent: :delete_all
    belongs_to :classification_tree_label, foreign_key: :id, inverse_of: :concept_scheme

    delegate :insert_all_classifications_by_path, to: :classification_tree_label

    # keep readonly until reverse triggers are defined and working
    def readonly?
      true
    end

    def visible?(context)
      visibility.include?(context)
    end

    def self.visible(context)
      where('? = ANY(visibility)', context)
    end

    def first_available_locale(*)
      :de
    end

    def to_api_default_values
      {
        '@id' => id,
        '@type' => 'skos:ConceptScheme'
      }
    end

    def to_hash
      { 'class_type' => self.class.to_s }
        .merge({ 'external_system' => external_system&.identifier })
        .merge(attributes)
    end
  end
end
