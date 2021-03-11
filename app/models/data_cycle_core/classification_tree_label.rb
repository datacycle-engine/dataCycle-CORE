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

    validates :name, presence: true

    acts_as_paranoid

    belongs_to :external_source, class_name: 'DataCycleCore::ExternalSystem'

    has_many :classification_trees, dependent: :destroy
    has_many :classification_aliases, through: :classification_trees, source: :sub_classification_alias do
      def roots
        joins(:classification_tree).where(classification_trees: { parent_classification_alias_id: nil })
      end
    end

    has_many :classifications, through: :classification_aliases
    has_many :things, -> { unscope(:order).distinct }, through: :classifications
    has_one :statistics, -> { readonly }, class_name: 'Statistics', foreign_key: 'id', inverse_of: :classification_tree_label
    after_update :add_things_cache_invalidation_job_update, :add_things_webhooks_job_update, if: :cached_attributes_changed?

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
            .find_or_initialize_by(name: attributes[:name], external_source: attributes[:external_source], uri: attributes[:uri])
        else
          classification_alias = classification_aliases.roots
            .find_or_initialize_by(name: attributes[:name], external_source: attributes[:external_source], uri: attributes[:uri])
        end

        if classification_alias.new_record?
          classification_alias.save!

          classification = Classification.create!(name: attributes[:name],
                                                  external_source: attributes[:external_source],
                                                  external_key: attributes[:external_key],
                                                  uri: attributes[:uri])

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

          next unless include_contents

          classification_alias.classifications.includes(things: :translations).map(&:things).flatten.each do |content|
            content&.translations&.each do |content_translation|
              row = Array.new(classification_alias.ancestors.count + 1)
              row += [
                content.template_name,
                content_translation.locale,
                content_translation.name
              ]
              csv << row
            end
          end
        end
      end
    end

    def ancestors
      []
    end

    def visible?(context)
      visibility.include?(context)
    end

    def self.visible(context)
      where('? = ANY(visibility)', context)
    end

    def first_available_locale(_locale)
      :de
    end

    def to_api_default_values
      {
        '@id' => id,
        '@type' => 'skos:ConceptScheme'
      }
    end

    private

    def cached_attributes_changed?
      return @cached_attributes_changed if defined? @cached_attributes_changed

      @cached_attributes_changed = saved_changes.key?('name') ||
                                   saved_changes.dig('visibility', 0)&.to_set&.^(saved_changes.dig('visibility', 1)&.to_set)&.include?('api')
    end

    def add_things_webhooks_job_update
      return unless things.exists?

      Delayed::Job.enqueue DataCycleCore::Jobs::CacheInvalidationJob.new(self.class.name, id, :execute_things_webhooks) unless Delayed::Job.exists?(queue: 'cache_invalidation', delayed_reference_type: "#{self.class.name.underscore}_execute_things_webhooks", delayed_reference_id: id, locked_at: nil)
    end

    def execute_things_webhooks
      things.find_each do |content|
        content.send(:execute_update_webhooks)
      end
    end

    def add_things_cache_invalidation_job_update
      Delayed::Job.enqueue DataCycleCore::Jobs::CacheInvalidationJob.new(self.class.name, id, :invalidate_things_cache) unless Delayed::Job.exists?(queue: 'cache_invalidation', delayed_reference_type: "#{self.class.name.underscore}_invalidate_things_cache", delayed_reference_id: id, locked_at: nil)
    end

    def invalidate_things_cache
      things.ids.each do |thing_id|
        Delayed::Job.enqueue DataCycleCore::Jobs::CacheInvalidationJob.new('DataCycleCore::Thing', thing_id, :invalidate_self) unless Delayed::Job.exists?(queue: 'cache_invalidation', delayed_reference_type: 'data_cycle_core/thing_invalidate_self', delayed_reference_id: thing_id, locked_at: nil)
      end
    end
  end
end
