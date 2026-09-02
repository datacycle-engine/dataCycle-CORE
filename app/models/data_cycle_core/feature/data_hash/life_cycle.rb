# frozen_string_literal: true

module DataCycleCore
  module Feature
    module DataHash
      module LifeCycle
        attr_accessor :life_cycle_changed

        def archive(user = nil)
          archive_id = DataCycleCore::Feature::LifeCycle.archive_id(self)
          return false if archive_id.nil?

          set_life_cycle_classification(archive_id, user, false, true)
        end

        # Counterpart of #archive: moves a content back to an active life-cycle stage ("feed wins"
        # un-archiving, see Generic::Common::ReactivateContents and dc:clean_up:archive_orphans).
        #
        # @param stage_name [String, nil] target stage, defaults to Feature::LifeCycle.active_name
        # @return [Boolean] false when the target stage is not part of this content's life cycle
        def reactivate(user = nil, stage_name: nil)
          active_id = DataCycleCore::Feature::LifeCycle.active_id(self, stage_name)
          return false if active_id.nil?

          set_life_cycle_classification(active_id, user, false, true)
        end

        def before_save_data_hash(options)
          super

          inherit_life_cycle_attributes(data_hash: options.data_hash) if options.new_content && !parent.nil?

          self.life_cycle_changed = options.data_hash.key?(DataCycleCore::Feature::LifeCycle.attribute_keys&.first) && !life_cycle_stage?(options.data_hash&.dig(DataCycleCore::Feature::LifeCycle.attribute_keys&.first)&.first)
        end

        def after_save_data_hash(_options)
          remove_instance_variable(:@life_cycle_stage) if instance_variable_defined?(:@life_cycle_stage)

          super
        end

        def set_life_cycle_classification(classification_id, user, prevent_history = false, update_computed = true)
          valid = true

          I18n.with_locale(first_available_locale) do
            valid = set_data_hash(data_hash: { DataCycleCore::Feature::LifeCycle.allowed_attribute_keys(self).presence&.first => [classification_id] }, current_user: user, prevent_history:, update_computed:)
          end

          return valid unless respond_to?(:children)

          children&.each do |child|
            I18n.with_locale(child.first_available_locale) do
              if child.life_cycle_classification?(classification_id)
                child.set_data_hash(data_hash: {
                  DataCycleCore::Feature::LifeCycle.allowed_attribute_keys(self).presence&.first => [classification_id]
                }, current_user: user, prevent_history:, update_computed:)
              end
            end
          end

          valid
        end

        private

        def inherit_life_cycle_attributes(data_hash:)
          I18n.with_locale(parent.first_available_locale) do
            key = DataCycleCore::Feature::LifeCycle.attribute_keys(self).first
            value = parent.try(DataCycleCore::Feature::LifeCycle.attribute_keys(parent).first)&.pluck(:id)

            data_hash[key] = value if key.present? && value.present?
          end
        end
      end
    end
  end
end
