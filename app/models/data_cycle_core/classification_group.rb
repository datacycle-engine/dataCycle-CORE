# frozen_string_literal: true

module DataCycleCore
  class ClassificationGroup < ApplicationRecord
    class PrimaryClassificationGroup < ApplicationRecord
      self.table_name = 'primary_classification_groups'
      self.primary_key = 'id'

      acts_as_paranoid

      belongs_to :external_source, class_name: 'DataCycleCore::ExternalSystem'
      belongs_to :classification
      belongs_to :classification_alias

      def readonly?
        true
      end
    end

    acts_as_paranoid

    belongs_to :external_source, class_name: 'DataCycleCore::ExternalSystem'
    belongs_to :classification
    belongs_to :classification_alias
  end
end
