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

    DEFAULT_ASSET_VERSIONS = [:original, :default].freeze

    def custom_validators
      if self.class.active_storage_activated?
        DataCycleCore.uploader_validations.dig(self.class.name.demodulize.underscore)&.except(:format)&.presence&.each do |validator, options|
          try("#{validator}_validation", options)
        end
      else
        DataCycleCore.uploader_validations.dig(file.class.name.underscore.match(/(\w+)_uploader/) { |m| m[1].to_sym })&.except(:format)&.presence&.each do |validator, options|
          try("#{validator}_validation", options)
        end
      end
    end

    def duplicate_candidates
      @duplicate_candidates ||= []
    end

    def duplicate_candidates_with_score
      @duplicate_candidates_with_score ||= []
    end

    # @todo: refactor after active_storage migration
    def update_asset_attributes
      return if file.blank?
      self.content_type = file.file.content_type
      self.file_size = file.file.size
      self.name ||= file.file.filename
      begin
        self.metadata = file.metadata&.to_utf8 if file.respond_to?(:metadata) && file.metadata.try(:to_utf8)&.to_json.present?
      rescue JSON::GeneratorError
        self.metadata = nil
      end
      self.duplicate_check = file.duplicate_check if file.respond_to?(:duplicate_check)
    end

    def method_missing(name, *args, &block)
      return super if self.class.active_storage_activated?
      if name.to_sym == :original
        file
      elsif file&.versions&.key?(name.to_sym)
        recreate_version(name) if args.dig(0, :recreate)
        file.send(name)
      else
        super
      end
    end

    def respond_to_missing?(method_name, include_private = false)
      return super if self.class.active_storage_activated?
      method_name.to_sym == :original || file&.versions&.key?(method_name.to_sym) || super
    end

    def duplicate
      new_asset = dup
      new_asset.file = file
      new_asset.save
      new_asset.persisted? ? new_asset : nil
    end

    # @todo: refactor after active_storage migration
    def self.active_storage_activated?
      true if DataCycleCore.experimental_features.dig('active_storage', 'enabled') && DataCycleCore.experimental_features.dig('active_storage', 'asset_types')&.include?(name)
    end

    # @todo: refactor after active_storage migration
    def self.extension_white_list
      uploaders[:file].new&.extension_white_list || []
    end

    # @todo: refactor after active_storage migration
    def self.content_type_white_list
      extension_white_list.map { |extension| MiniMime.lookup_by_extension(extension)&.extension }
    end

    private

    # @todo: carrierwave specific method
    def recreate_version(version_name = nil)
      return if file.try(version_name)&.file&.exists?
      self.process_file_upload = true
      file.recreate_versions!(version_name)
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
      return unless self.class.active_storage_activated?
      return if self.class.content_type_white_list.include?(MiniMime.lookup_by_content_type(file.content_type)&.extension)

      errors.add :file, {
        path: 'uploader.validation.format_not_supported',
        substitutions: {
          data: {
            value: file.content_type
          }
        }
      }
    end

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

    # @todo: carrierwave specific method
    def remove_directory
      return if self&.file&.store_dir.blank? || self&.file&.store_dir&.end_with?('/file/')
      FileUtils.remove_dir(Rails.public_path.join(file.store_dir), force: true) # deletes only EMPTY directories!
    end
  end
end
