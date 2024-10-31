# frozen_string_literal: true

module DataCycleCore
  module Feature
    class CustomAssetPreviewer < Base
      class << self
        def previewer_options(previewer)
          configuration["#{previewer}_options"].with_indifferent_access
        end

        def update_computed_for_templates(template_names:, webhooks: true)
          things = DataCycleCore::Thing.all
          things = things.where(template_name: template_names) if template_names.present?

          things.find_in_batches do |batch|
            pid = Process.fork do
              batch.each do |thing|
                next unless thing.try(:asset)&.file&.attached?

                thing.asset.file.preview({}).send(:process)
                thing.prevent_webhooks = true unless webhooks
                computed_keys = thing.property_definitions.slice(*thing.computed_property_names).select { |k, v| Array.wrap(v.dig('compute', 'parameters')).include?('asset') && k.ends_with?('_url') && k != 'content_url' }.keys

                thing.update_computed_values(keys: computed_keys)
              rescue ActiveStorage::FileNotFoundError
                nil
              end
            end

            Process.waitpid(pid)
          end
        end
      end
    end
  end
end
