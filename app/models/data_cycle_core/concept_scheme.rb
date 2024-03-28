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

    def self.create(attributes = nil, &)
      if attributes.is_a?(Array)
        attributes.collect { |attr| create(attr, &) }
      else
        attributes[:external_source_id] = attributes.delete(:external_system_id) if attributes.key?(:external_system_id)
        attributes[:external_source] = attributes.delete(:external_system) if attributes.key?(:external_system)

        object = ClassificationTreeLabel.new(attributes, &)
        object.save

        object.valid? ? find_by(id: object.id) : object
      end
    end

    def self.create!(attributes = nil, &)
      if attributes.is_a?(Array)
        attributes.collect { |attr| create!(attr, &) }
      else
        attributes[:external_source_id] = attributes.delete(:external_system_id) if attributes.key?(:external_system_id)
        attributes[:external_source] = attributes.delete(:external_system) if attributes.key?(:external_system)

        object = ClassificationTreeLabel.new(attributes, &)
        object.save!

        find(object.id)
      end
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
