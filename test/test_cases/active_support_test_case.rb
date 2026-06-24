# frozen_string_literal: true

require 'helpers/minitest_hook_helper'
require 'helpers/active_storage_helper'

module DataCycleCore
  module TestCases
    class ActiveSupportTestCase < ActiveSupport::TestCase
      include DataCycleCore::MinitestHookHelper
      include DataCycleCore::ActiveStorageHelper

      private

      def create_content(template_name, data = {}, user = nil)
        DataCycleCore::TestPreparations.create_content(template_name:, data_hash: data, user:)
      end

      def update_content(content, data = {}, user = nil)
        content.set_data_hash(data_hash: data, current_user: user)
      end

      def get_classification_ids(tree_name, *alias_names)
        DataCycleCore::Concept.for_tree(tree_name).with_name(alias_names).pluck(:classification_id)
      end

      def get_concept_ids(tree_name, *alias_names)
        DataCycleCore::Concept.for_tree(tree_name).with_name(alias_names).pluck(:id)
      end
    end
  end
end
