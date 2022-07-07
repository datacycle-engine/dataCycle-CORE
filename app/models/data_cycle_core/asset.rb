# frozen_string_literal: true

module DataCycleCore
  class Asset < ApplicationRecord
    attribute :type, :string, default: -> { name }
    belongs_to :creator, class_name: 'DataCycleCore::User'

    before_create :update_asset_attributes
    validates :file, presence: true
    validate :custom_validators

    include AssetHelpers

    has_one :asset_content, dependent: :destroy
    has_one :thing, through: :asset_content, source: 'content_data'

    def custom_validators
      DataCycleCore.uploader_validations.dig(file.class.name.underscore.match(/(\w+)_uploader/) { |m| m[1].to_sym })&.except(:format)&.presence&.each do |validator, options|
        try("#{validator}_validation", options)
      end
    end

    def self.extension_white_list
      uploaders[:file].new&.extension_white_list || []
    end

    def duplicate_candidates
      @duplicate_candidates ||= []
    end

    def duplicate_candidates_with_score
      @duplicate_candidates_with_score ||= []
    end

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

    def self.active_storage_activated?
      true if DataCycleCore.experimental_features.dig('active_storage', 'enabled') && DataCycleCore.experimental_features.dig('active_storage', 'asset_types')&.include?(name)
    end

    private

    def recreate_version(version_name = nil)
      return if file.try(version_name)&.file&.exists?
      self.process_file_upload = true
      file.recreate_versions!(version_name)
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

    def remove_directory
      return if self&.file&.store_dir.blank? || self&.file&.store_dir&.end_with?('/file/')
      FileUtils.remove_dir(Rails.public_path.join(file.store_dir), force: true) # deletes only EMPTY directories!
    end
  end
end
