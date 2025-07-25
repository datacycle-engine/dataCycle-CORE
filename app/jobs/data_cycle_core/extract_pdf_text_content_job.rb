# frozen_string_literal: true

module DataCycleCore
  class ExtractPdfTextContentJob < UniqueApplicationJob
    PRIORITY = 12

    def priority
      PRIORITY
    end

    def delayed_reference_id
      arguments[0]
    end

    def perform(id)
      asset = DataCycleCore::Asset.find_by(id:)

      return if asset.nil? || asset.file_size.blank? || asset.file_size.zero?

      reader = PDF::Reader.new(asset.file.service.path_for(asset.file.key))
      content = reader.try(:pages)&.map { |page| page.try(:text)&.delete("\u0000") }&.join(' ')

      return if content.blank?

      metadata = asset.metadata || {}
      metadata['content'] = content

      asset.update!(metadata:)

      # TODO: Trigger update for thing computed/default_values
    end
  end
end
