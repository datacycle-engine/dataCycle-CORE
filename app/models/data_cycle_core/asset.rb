# frozen_string_literal: true

# @todo: refactor after active_storage migration
# This class should not be used directly for any assets.
module DataCycleCore
  class Asset < ApplicationRecord
    attribute :type, :string, default: -> { name }
    belongs_to :creator, class_name: 'DataCycleCore::User'

    before_create :update_asset_attributes

    validates :file, presence: true
    validate :custom_validators
    validate :file_extension_validation

    include AssetHelpers

    has_one :asset_content, dependent: :destroy
    has_one :thing, through: :asset_content, source: 'content_data'

    # @todo disable defualt for audio/pdf
    DEFAULT_ASSET_VERSIONS = [:original, :default].freeze

    def custom_validators
      DataCycleCore.uploader_validations.dig(self.class.name.demodulize.underscore)&.except(:format)&.presence&.each do |validator, options|
        try("#{validator}_validation", options)
      end
    end

    def duplicate_candidates
      @duplicate_candidates ||= []
    end

    def duplicate_candidates_with_score
      @duplicate_candidates_with_score ||= []
    end

    def update_asset_attributes
      return if file.blank?
      self.content_type = file.blob.content_type
      self.file_size = file.blob.byte_size
      self.name ||= file.blob.filename
      begin
        self.metadata = metadata_from_blob
      rescue JSON::GeneratorError
        self.metadata = nil
      end
    end

    def duplicate
      new_asset = dup
      new_asset.file.attach(io: File.open(file.service.path_for(file.key)), filename: file.filename)
      new_asset.save
      new_asset.persisted? ? new_asset : nil
    end

    # @todo: refactor after active_storage migration
    def self.extension_white_list
      []
    end

    # @todo: refactor after active_storage migration
    def self.content_type_white_list
      extension_white_list.map { |extension| MiniMime.lookup_by_extension(extension)&.extension }
    end

    private

    def metadata_from_blob
      nil
    end

    def load_file_from_remote_file_url
      return if remote_file_url.blank?

      @retry_count = 0

      begin
        tmp_uri = URI.parse(remote_file_url)
        tmp_file = tmp_uri.open
        filename = File.basename(tmp_uri.path)
        file.attach(io: tmp_file, filename: filename)
      rescue StandardError => e
        raise DataCycleCore::Error::Asset::RemoteFileDownloadError, "could not download file: #{e.message}" if @retry_count >= 3

        @retry_count += 1
        sleep 5
        retry
      end
    end

    def file_extension_validation
      return if file.present? && self.class.content_type_white_list.include?(MiniMime.lookup_by_content_type(file.content_type)&.extension)

      errors.add :file, {
        path: 'uploader.validation.format_not_supported',
        substitutions: {
          data: {
            value: file.content_type
          }
        }
      }
    end

    # @todo: refactor after active_storage migration
    def file_size_validation(options)
      return unless file.size > options.dig(:file_size, :max).to_i

      errors.add :file, {
        path: 'uploader.validation.file_size.max',
        substitutions: {
          data: {
            method: 'number_to_human_size',
            value: options.dig(:file_size, :max).to_i
          }
        }
      }
    end
  end
end
