# frozen_string_literal: true

module DataCycleCore
  module Content
    module Features
      def set_data_hash_attribute(key, value, current_user, save_time = Time.zone.now)
        @save_time = save_time
        @current_user = current_user
        key_hash = schema.dig('properties', key)
        return if key_hash.nil?
        ActiveRecord::Base.transaction do
          storage_cases_set(key, value, key_hash)
        end
      end

      def set_life_cycle_classification(classification_tree_label, classification_id, user)
        set_data_hash_attribute(classification_tree_label, [classification_id], user)

        return unless respond_to?(:children)

        children&.each do |child|
          child.set_data_hash_attribute(classification_tree_label, [classification_id], user) if DataCycleCore::Feature::LifeCycle.ordered_classifications(child)&.values&.map { |value| value[:id] }&.include?(classification_id)
        end
      end

      def get_inherit_datahash(parent)
        data_hash = get_data_hash

        I18n.with_locale(parent.first_available_locale) do
          parent_data_hash = parent.get_data_hash

          DataCycleCore.inheritable_attributes.each do |attribute_key|
            parent_data = parent_data_hash[attribute_key]
            data_hash[attribute_key] = parent_data if parent_data.present?
          end

          data_hash[DataCycleCore::Feature::LifeCycle.attribute_keys.first] = parent_data_hash[DataCycleCore::Feature::LifeCycle.attribute_keys.first] if DataCycleCore::Feature::LifeCycle.enabled?
        end

        data_hash.compact!
      end
    end
  end
end
