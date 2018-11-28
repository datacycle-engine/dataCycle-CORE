# frozen_string_literal: true

module DataCycleCore
  module Feature
    module DataHash
      module LifeCycle
        def self.prepended(base)
          base.before_save_data_hash :set_changed_life_cycle_stage, if: proc {
            @data_hash&.dig(DataCycleCore::Feature::LifeCycle.attribute_keys&.first)&.present? &&
              life_cycle_stage&.id != @data_hash&.dig(DataCycleCore::Feature::LifeCycle.attribute_keys&.first)&.first
          }
          base.before_save_data_hash :inherit_life_cycle_attributes, if: -> { @new_content && @source.present? }
        end

        def set_life_cycle_classification(classification_id, user)
          valid = {}
          I18n.with_locale(first_available_locale) do
            valid = set_data_hash(data_hash: { DataCycleCore::Feature::LifeCycle.allowed_attribute_keys(self).presence&.first => [classification_id] }, current_user: user, partial_update: true)
          end

          return valid unless respond_to?(:children)

          children&.each do |child|
            I18n.with_locale(child.first_available_locale) do
              if child.life_cycle_classification?(classification_id)
                child.set_data_hash(data_hash: {
                  DataCycleCore::Feature::LifeCycle.allowed_attribute_keys(self).presence&.first => [classification_id]
                }, current_user: user, partial_update: true)
              end
            end
          end
          valid
        end

        private

        def inherit_life_cycle_attributes
          I18n.with_locale(@source.first_available_locale) do
            source_data_hash = {}
            DataCycleCore::Feature::LifeCycle.allowed_attribute_keys(self).each do |key|
              source_data_hash[key] = @source.try(key)&.ids if @source.try(key)&.ids.present?
            end
            @data_hash = source_data_hash.merge(@data_hash)
          end
        end

        def set_changed_life_cycle_stage
          @changed_life_cycle_stage = @data_hash&.dig(DataCycleCore::Feature::LifeCycle.attribute_keys&.first)&.first
        end
      end
    end
  end
end
