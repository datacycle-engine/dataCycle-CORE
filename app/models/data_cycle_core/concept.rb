# frozen_string_literal: true

module DataCycleCore
  class Concept < ApplicationRecord
    extend ::Mobility
    translates :name, :description, column_suffix: '_i18n', backend: :jsonb
    default_scope { i18n.order(order_a: :asc, id: :asc) }
    before_validation :set_internal_name
    validates :internal_name, presence: true

    attr_accessor :prevent_webhooks

    belongs_to :external_system
    belongs_to :concept_scheme

    has_many :mapped_concept_links, -> { where(link_type: 'related') }, inverse_of: :parent, class_name: 'ConceptLink', foreign_key: :parent_id
    has_many :mapped_concepts, through: :mapped_concept_links, source: :child

    has_many :mapped_inverse_concept_links, -> { where(link_type: 'related') }, inverse_of: :child, class_name: 'ConceptLink', foreign_key: :child_id
    has_many :mapped_inverse_concepts, through: :mapped_inverse_concept_links, source: :parent

    has_one :parent_concept_link, -> { where(link_type: 'broader') }, inverse_of: :child, class_name: 'ConceptLink', foreign_key: :child_id
    has_one :parent, through: :parent_concept_link

    has_many :children_concept_links, -> { where(link_type: 'broader') }, inverse_of: :parent, class_name: 'ConceptLink', foreign_key: :parent_id
    has_many :children, through: :children_concept_links

    belongs_to :classification
    belongs_to :classification_alias, foreign_key: :id, inverse_of: :concept

    belongs_to :classification_alias_path, primary_key: :id, foreign_key: :id, class_name: 'ClassificationAlias::Path', inverse_of: :concept

    has_many :classification_polygons, dependent: :delete_all, foreign_key: :classification_alias_id, inverse_of: false

    delegate :visible?, to: :concept_scheme

    scope :in_context, ->(context) { includes(:concept_scheme).where('concept_schemes.visibility && ARRAY[?]::varchar[]', Array.wrap(context)).references(:concept_scheme) }
    scope :search, ->(q) { includes(:classification_alias_path).where("ARRAY_TO_STRING(full_path_names, ' | ') ILIKE :q OR (concepts.description_i18n ->> :locale) ILIKE :q OR (concepts.name_i18n ->> :locale) ILIKE :q", { locale: I18n.locale, q: "%#{q}%" }).references(:classification_alias_path) }
    scope :by_full_paths, ->(full_paths) { includes(:classification_alias_path).where('classification_alias_paths.full_path_names IN (?)', Array.wrap(full_paths).map { |p| p.split('>').map(&:strip).reverse.to_pg_array }).references(:classification_alias_path) } # rubocop:disable Rails/WhereEquals

    validate :validate_color_format

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
        attributes[:classification_tree_label_id] = attributes.delete(:concept_scheme_id) if attributes.key?(:concept_scheme_id)
        attributes[:classification_tree_label] = attributes.delete(:concept_scheme)&.classification_tree_label if attributes.key?(:concept_scheme)
        attributes[:parent_classification_alias] = attributes.delete(:parent)&.classification_alias if attributes.key?(:parent)

        ca = ClassificationAlias.create(attributes.slice(:name, :description, :external_source, :external_source_id, :external_key, :assignable, :internal, :uri, :ui_configs, :created_at, :updated_at), &)
        c = Classification.create(attributes.slice(:name, :description, :external_source, :external_source_id, :external_key, :uri, :created_at, :updated_at), &)
        ClassificationGroup.create(classification: c, classification_alias: ca, &)
        ClassificationTree.create(sub_classification_alias: ca, **attributes.slice(:classification_tree_label_id, :classification_tree_label, :parent_classification_alias), &)

        find_by(id: ca.id)
      end
    end

    def self.create!(attributes = nil, &)
      if attributes.is_a?(Array)
        attributes.collect { |attr| create!(attr, &) }
      else
        attributes[:external_source_id] = attributes.delete(:external_system_id) if attributes.key?(:external_system_id)
        attributes[:external_source] = attributes.delete(:external_system) if attributes.key?(:external_system)
        attributes[:classification_tree_label_id] = attributes.delete(:concept_scheme_id) if attributes.key?(:concept_scheme_id)
        attributes[:classification_tree_label] = attributes.delete(:concept_scheme)&.classification_tree_label if attributes.key?(:concept_scheme)
        attributes[:parent_classification_alias] = attributes.delete(:parent)&.classification_alias if attributes.key?(:parent)

        ca = ClassificationAlias.create!(attributes.slice(:name, :description, :external_source, :external_source_id, :external_key, :assignable, :internal, :uri, :ui_configs, :created_at, :updated_at), &)
        c = Classification.create!(attributes.slice(:name, :description, :external_source, :external_source_id, :external_key, :uri, :created_at, :updated_at), &)
        ClassificationGroup.create!(classification: c, classification_alias: ca, &)
        ClassificationTree.create!(sub_classification_alias: ca, **attributes.slice(:classification_tree_label_id, :classification_tree_label, :parent_classification_alias), &)

        find(ca.id)
      end
    end

    def self.for_tree(tree_name)
      return none if tree_name.blank?

      includes(:concept_scheme).where(concept_scheme: { name: tree_name })
    end

    def self.from_tree(tree_name)
      for_tree(tree_name)
    end

    def self.with_name(*names)
      where(name: names.flatten)
    end

    def self.with_internal_name(*names)
      where(internal_name: names.flatten)
    end

    def self.without_name(*names)
      where.not(name: names.flatten)
    end

    def self.order_by_similarity(term)
      max_cardinality = ClassificationAlias::Path.pluck(Arel.sql('MAX(CARDINALITY(full_path_names))')).max

      joins(:classification_alias_path).reorder(nil).order(
        [
          Arel.sql(
            (1..max_cardinality).map { |c|
              "COALESCE(10 ^ #{max_cardinality - c} * (1 - (full_path_names[#{c}] <-> :term)), 0)"
            }.join(' + ') + ' DESC'.to_s
          ),
          term:
        ]
      )
    end

    def full_path
      classification_alias_path&.full_path_names&.reverse&.join(' > ')
    end

    def translated_locales
      @translated_locales ||= (
        name_i18n.compact_blank.keys.map(&:to_sym) +
        description_i18n.compact_blank.keys.map(&:to_sym)
      ).uniq
    end
    alias available_locales translated_locales

    def first_available_locale(locale = nil)
      (Array.wrap(locale).map(&:to_sym).sort_by { |t| I18n.available_locales.index t }.push(I18n.locale) & translated_locales).first || translated_locales.min_by { |t| I18n.available_locales.index t }
    end

    def to_api_default_values
      {
        '@id' => id,
        '@type' => 'skos:Concept'
      }
    end

    def to_hash
      { 'class_type' => self.class.to_s }
        .merge({ 'external_system' => external_system&.identifier })
        .merge(attributes)
    end

    def color
      ui_configs.dig('color')
    end

    def color?
      color.present?
    end

    def icon
      icon = DataCycleCore.classification_icons[id] || DataCycleCore.classification_icons[concept_scheme&.id]

      return if icon.blank?

      DataCycleCore::LocalizationService.view_helpers.dc_image_url("icons/#{icon}")
    end

    def icon?
      icon.present?
    end

    def to_sync_data
      Rails.cache.fetch("sync_api/v1/concepts/#{id}/#{updated_at}", expires_in: 1.year + Random.rand(7.days)) do
        next if available_locales.exclude?(I18n.locale)

        as_json(
          only: [:id, :external_key, :uri, :order_a, :concept_scheme_id],
          methods: [:parent_id, :name, :description]
        )
        .merge({ 'external_system_identifier' => external_system&.identifier })
        .compact_blank
      end
    end

    def self.to_sync_data
      includes(:parent, :external_system).map(&:to_sync_data).compact
    end

    def parent_id
      parent&.id
    end

    private

    def validate_color_format
      return unless color?

      errors.add(:ui_configs, :color_format) unless /^#((?:\h{1,2}){3,4})$/i.match?(color)
    end

    def set_internal_name
      return unless name_i18n_changed?

      self.internal_name = name_i18n.values_at(*I18n.available_locales.map(&:to_s)).compact_blank.first
    end
  end
end
