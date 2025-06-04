# frozen_string_literal: true

module DataCycleCore
  module Content
    module Extensions
      module LinkedInText
        def remove_id_from_text_props(data_hash:, linked_id:, keys: nil)
          regex = %r{<span class="[\w\d\s\-\_]*dc--contentlink[\w\d\s\-\_]*"[\w\d\s\-\_\"\']*data-href="#{linked_id}"[\w\d\s\-\_\"\']*>(.*?)</span>}

          Array.wrap(keys.presence || text_with_linked_property_names).each do |key|
            value = send(key)
            data_hash[key] = value.gsub(regex, '\1') if value.present?
          end

          data_hash
        end

        def add_remove_linked_from_text_job
          return if try(:linked_to_text).blank?

          DataCycleCore::RemoveContentReferencesFromTextJob.perform_later(
            id,
            try(:linked_to_text).pluck(:id)
          )
        end
      end
    end
  end
end
