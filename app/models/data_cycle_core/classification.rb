module DataCycleCore
  class Classification < ApplicationRecord

    belongs_to :external_sources

    acts_as_paranoid

    DataCycleCore.content_tables.each do |content_table|
      has_many :classification_contents, dependent: :destroy
      has_many content_table.to_sym, through: :classification_contents, source: "content_data", source_type: "DataCycleCore::#{content_table.singularize.classify}"

      has_many :classification_content_histories, class_name: "DataCycleCore::ClassificationContent::History"
      has_many "#{content_table.singularize}_histories".to_sym, through: :classification_content_histories, source: "content_data_history", source_type: "DataCycleCore::#{content_table.singularize.classify}::History"
    end

    has_many :classification_groups, dependent: :destroy
    has_many :classification_aliases, through: :classification_groups

    has_one :primary_classification_group, -> { min_by(&:created_at) }, class_name: ClassificationGroup

    def primary_classification_group
      classification_groups.min_by(&:created_at)
    end

    def primary_classification_alias
      primary_classification_group.classification_alias
    end

    def ancestors
      Rails.cache.fetch("#{cache_key}/ancestors", expires_in: 10.minutes) do
        [primary_classification_alias] + primary_classification_alias.ancestors
      end
    end

  end
end
