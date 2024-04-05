# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Segments
      class AssetByUserGroupsForDataLink < Base
        attr_reader :subject

        def initialize
          @subject = DataCycleCore::Asset
        end

        def conditions
          { creator_id: user.include_groups_user_ids, type: 'DataCycleCore::TextFile' }
        end

        def to_descriptions
          subject_name = DataCycleCore::TextFile.model_name.human(locale:)

          [
            {
              permission: to_permission(subject: DataCycleCore::TextFile, translated_subject: subject_name),
              restrictions: to_restrictions(subject: DataCycleCore::TextFile, translated_subject: subject_name),
              segment: self
            }
          ]
        end
      end
    end
  end
end
