# frozen_string_literal: true

module DataCycleCore
  class ConceptScheme < ApplicationRecord
    validates :name, presence: true

    belongs_to :external_system

    has_many :concepts, dependent: :delete_all
    belongs_to :classification_tree_label, foreign_key: :id, inverse_of: :concept_scheme

    scope :by_external_systems_and_keys, ->(values) { where(Array.new(values.size) { '(external_system_id = ? AND external_key = ?)' }.join(' OR '), *values.pluck(:external_system_id, :external_key).flatten) }

    delegate :insert_all_classifications_by_path, to: :classification_tree_label
    delegate :upsert_all_external_classifications, to: :classification_tree_label

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

    def to_select_option(locale = DataCycleCore.ui_locales.first)
      DataCycleCore::Filter::SelectOption.new(
        id,
        ActionController::Base.helpers.safe_join([
          ActionController::Base.helpers.tag.i(class: 'fa dc-type-icon concept_scheme-icon'),
          name
        ].compact, ' '),
        model_name.param_key,
        "#{model_name.human(count: 1, locale:)}: #{name}"
      )
    end

    def self.to_select_options(locale = DataCycleCore.ui_locales.first)
      all.map { |v| v.to_select_option(locale) }
    end

    def to_sync_data
      Rails.cache.fetch("sync_api/v1/concept_scheme/#{id}/#{updated_at}", expires_in: 1.year + Random.rand(7.days)) do
        as_json(only: [:id, :name])
        .merge({ 'external_system_identifier' => external_system&.identifier })
        .compact_blank
      end
    end

    def self.to_sync_data
      includes(:external_system).map(&:to_sync_data)
    end
  end
end
