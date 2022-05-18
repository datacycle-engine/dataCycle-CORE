# frozen_string_literal: true

module DataCycleCore
  module Feature
    module DataHash
      module TranslationOfWork
        def before_save_data_hash(options)
          add_translation_of_work(**options.to_h.slice(:data_hash, :source)) if options.new_content && !options.source.nil?

          super
        end

        private

        def translation_of_work_allowed?(source)
          [
            source.id.present?,
            linked_property_names.include?(DataCycleCore::Feature::TranslationOfWork.attribute_keys.first),
            template_name == source.template_name,
            I18n.locale.to_s != source.first_available_locale.to_s
          ].all?
        end

        def add_translation_of_work(data_hash:, source:)
          return unless translation_of_work_allowed?(source)

          data_hash.reverse_merge!({ DataCycleCore::Feature::TranslationOfWork.attribute_keys.first => Array.wrap(source.id) })
        end
      end
    end
  end
end
