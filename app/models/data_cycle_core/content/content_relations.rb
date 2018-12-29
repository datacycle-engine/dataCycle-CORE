# frozen_string_literal: true

module DataCycleCore
  module Content
    module ContentRelations
      extend ActiveSupport::Concern

      module ClassMethods
        def content_relations(options = {}, &block)
          table_given = options[:table_name]
          postfix = options[:postfix]

          self_class = "DataCycleCore::#{table_given.classify}"
          self_class += "::#{postfix.capitalize}" unless postfix.nil?

          classification_content_table = 'classification_content'
          classification_content_table += "_#{postfix}" unless postfix.nil?
          class_name = 'DataCycleCore::ClassificationContent'
          class_name += "::#{postfix.capitalize}" unless postfix.nil?
          content_name = 'content_data'
          content_name += "_#{postfix}" unless postfix.nil?

          # relation content to classification
          has_many classification_content_table.to_sym, class_name: class_name, foreign_key: content_name.foreign_key, dependent: :destroy
          has_many :classifications, through: classification_content_table.to_sym
          has_many :classification_groups, through: :classifications
          has_many :classification_aliases, through: :classification_groups
          has_many :display_classification_aliases, -> { where('classification_aliases.internal = ?', false) }, through: :classification_groups, source: :classification_alias
          has_many :primary_classification_groups, through: :classifications
          has_many :primary_classification_aliases, through: :primary_classification_groups, source: :classification_alias

          # relation content to all other contents
          has_many :content_content_b, class_name: 'DataCycleCore::ContentContent', foreign_key: 'content_b_id', dependent: :destroy, inverse_of: :content_b
          has_many :content_content_b_history, class_name: 'DataCycleCore::ContentContent::History', as: :content_b_history, dependent: :destroy
          has_many :content_content_a, class_name: 'DataCycleCore::ContentContent', foreign_key: 'content_a_id', dependent: :destroy, inverse_of: :content_a
          has_many :content_content_a_history, class_name: 'DataCycleCore::ContentContent::History', foreign_key: 'content_a_history_id', dependent: :destroy, inverse_of: :content_a_history

          belongs_to :external_source
          belongs_to :created_by_user, foreign_key: :created_by, class_name: 'DataCycleCore::User'
          belongs_to :updated_by_user, foreign_key: :updated_by, class_name: 'DataCycleCore::User'
          belongs_to :deleted_by_user, foreign_key: :deleted_by, class_name: 'DataCycleCore::User'

          belongs_to :parent, class_name: self_class, foreign_key: 'is_part_of', inverse_of: :children, touch: false
          has_many :children, class_name: self_class, foreign_key: 'is_part_of', inverse_of: :parent, dependent: :destroy

          has_many :watch_list_data_hashes, as: :hashable, dependent: :destroy
          has_many :watch_lists, through: :watch_list_data_hashes

          has_many :subscriptions, as: :subscribable, dependent: :destroy
          has_many :data_link_content_items, as: :content
          has_many :indirect_data_links, through: :data_link_content_items
          has_many :data_links, as: :item, dependent: :destroy
        end
      end

      def assigned_classification_aliases
        primary_classification_aliases
      end

      def mapped_classification_aliases
        classification_aliases.where.not(id: primary_classification_aliases.pluck(:id))
      end
    end
  end
end
