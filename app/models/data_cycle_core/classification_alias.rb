# frozen_string_literal: true

module DataCycleCore
  class ClassificationAlias < ApplicationRecord
    class Path < ApplicationRecord
      self.table_name = 'classification_alias_paths'

      belongs_to :classification_alias, foreign_key: 'id'

      def readonly?
        true
      end
    end

    attr_accessor :content_template

    acts_as_paranoid

    belongs_to :external_source

    belongs_to :classification_alias_path, class_name: 'Path', primary_key: 'id', foreign_key: 'id'

    has_one :classification_tree, dependent: :destroy
    has_one :parent_classification_alias, through: :classification_tree

    has_one :classification_tree_with_deleted, -> { with_deleted }, class_name: 'ClassificationTree', foreign_key: 'classification_alias_id'
    has_one :classification_tree_label, through: :classification_tree_with_deleted

    has_one :parent_classification_alias_with_deleted, through: :classification_tree_with_deleted, source: :parent_classification_alias

    has_many :sub_classification_trees, class_name: 'ClassificationTree', foreign_key: 'parent_classification_alias_id', dependent: :destroy
    has_many :sub_classification_alias, through: :sub_classification_trees

    has_many :classification_groups, dependent: :destroy
    has_many :classifications, -> { order(:name) }, through: :classification_groups

    has_many :descendant_paths, ->(a) { unscope(:where).where('ancestor_ids @> ARRAY[?]::uuid[]', a.id) },
             class_name: 'Path'
    has_many :descendants, through: :descendant_paths, source: :classification_alias

    after_update :update_primary_classification

    def self.for_tree(tree_name)
      joins(classification_tree: :classification_tree_label)
        .where('classification_trees' => { 'classification_tree_labels' => { 'name' => tree_name } })
    end

    def self.with_name(*names)
      where(name: names.flatten)
    end

    def self.without_name(*names)
      where.not(name: names.flatten)
    end

    def self.with_descendants
      query = is_a?(ActiveRecord::Relation) ? self : all

      query.unscoped.joins(:classification_alias_path).where('full_path_ids && ARRAY[?]::uuid[]', query.pluck(:id))
    end

    def self.search(q)
      joins(:classification_alias_path).where("ARRAY_TO_STRING(full_path_names, ' | ') ILIKE ?", "%#{q}%")
    end

    def self.order_by_similarity(term)
      term = ActiveRecord::Base.connection.quote(term)

      max_cardinality = Path.all.pluck('MAX(CARDINALITY(full_path_names))').max

      joins(:classification_alias_path).order(
        ActiveRecord::Base.send(:sanitize_sql_for_order,
                                (1..max_cardinality).map { |c|
                                  "COALESCE(10 ^ #{max_cardinality - c} * (1 - (full_path_names[#{c}] <-> #{term})), 0)"
                                }.join(' + ') + ' DESC')
      )
    end

    def primary_classification
      classifications.min_by { |c| (created_at - c.created_at).abs }
    end

    def linked_contents
      classifications.includes(:classification_contents).map(&:classification_contents).flatten + sub_classification_alias.includes(classifications: :classification_contents).with_descendants.map { |c|
        c.classifications.includes(:classification_contents).map(&:classification_contents)
      }.flatten
    end

    def ancestors
      Rails.cache.fetch("#{cache_key}/ancestors", expires_in: 10.minutes) do
        if parent_classification_alias_with_deleted
          [parent_classification_alias_with_deleted] + parent_classification_alias_with_deleted.ancestors
        else
          [classification_tree_with_deleted.classification_tree_label_with_deleted]
        end
      end
    end

    def full_path
      classification_alias_path.full_path_names.reverse.join(' > ')
    end

    def self.with_content_templates
      templates = DataCycleCore.content_tables.map { |table|
        "DataCycleCore::#{table.classify}".constantize
      }.map { |c|
        c.where(template: true)
      }.flatten.compact.uniq

      all.map do |c|
        c.content_template = c.find_content_template(templates)
        c
      end
    end

    def find_content_template(templates)
      template = templates.select { |t| t.schema&.dig('properties', 'data_type', 'default_value') == name }

      if template.blank? && ancestors&.first.is_a?(DataCycleCore::ClassificationAlias)
        ancestors.first.find_content_template(templates)
      elsif template.blank?
        return nil
      else
        template.first
      end
    end

    private

    def update_primary_classification
      return unless saved_change_to_attribute?('name')
      primary_classification.tap do |c|
        c.name = name
        c.save!
      end
    end
  end
end
