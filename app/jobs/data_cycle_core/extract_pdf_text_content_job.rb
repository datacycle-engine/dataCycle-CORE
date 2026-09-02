# frozen_string_literal: true

require 'pdf-reader'

module DataCycleCore
  class ExtractPdfTextContentJob < UniqueApplicationJob
    discard_on PDF::Reader::MalformedPDFError
    queue_with_priority 12
    limits_concurrency key: ->(*args) { args[0] }

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
