# frozen_string_literal: true

module DataCycleCore
  class Asset < ApplicationRecord
    attribute :type, :string, default: name
    belongs_to :creator, class_name: 'DataCycleCore::User'
    mount_uploader :file, DataCycleFileUploader
    before_create :update_asset_attributes
    process_in_background :file
    validates :file, presence: true
    validates_integrity_of :file
    validate :custom_validators
    after_destroy :remove_directory

    include AssetHelpers

    has_many :asset_contents, dependent: :destroy
    has_many :things, through: :asset_contents, source: 'content_data'

    def custom_validators
      DataCycleCore.uploader_validations.dig(file.class.name.demodulize.underscore.remove('_uploader').to_sym)&.except(:format)&.presence&.each do |validator, options|
        try("#{validator}_validation", options)
      end
    end

    def duplicate_candidates
      @duplicate_candidates ||= []
    end

    def duplicate_candidates_with_score
      @duplicate_candidates_with_score ||= []
    end

    def dynamic_version_definition(name)
      @dynamic_version_definition ||= Hash.new do |h, key|
        h[key.to_s] = asset_contents&.first&.asset_version_definition(key)
      end
      @dynamic_version_definition[name.to_s]
    end

    def update_asset_attributes
      return if file.blank?
      self.content_type = file.file.content_type
      self.file_size = file.size
      self.name ||= file.file.filename
      begin
        self.metadata = file.metadata.to_utf8 if file.respond_to?(:metadata) && file.metadata.try(:to_utf8)&.to_json.present?
      rescue JSON::GeneratorError
        self.metadata = nil
      end
      self.duplicate_check = file.duplicate_check if file.respond_to?(:duplicate_check)
    end

    def method_missing(name, *args, &block)
      if dynamic_version_definition(name.to_s).present?
        dynamic_version(name.to_sym, args.dig(0, :recreate))
      elsif file&.try(name)
        recreate_version(name) if args.dig(0, :recreate)
        file.try(name)
      else
        super
      end
    end

    def respond_to_missing?(method_name, include_private = false)
      dynamic_version_definition(method_name.to_s).present? || file&.try(method_name) || super
    end

    def dynamic_version(version_name, process = false)
      version_options = dynamic_version_definition(version_name)

      return if version_options.blank?

      file.dynamic_version(name: version_name, options: version_options, process: process)
    end

    def create_dynamic_versions
      asset_contents&.first&.asset_version_definition.presence&.each do |version_name, version_options|
        file.dynamic_version(name: version_name.to_sym, options: version_options, delay: true)
      end
    end

    private

    def recreate_version(version_name = nil)
      return if file.try(version_name)&.file&.exists?
      self.process_file_upload = true
      file.recreate_versions!(version_name)
    end

    def file_size_validation(_options)
      errors.add :file, I18n.t('uploader.validation.file_size.max', data: ApplicationController.helpers.number_to_human_size(options.dig(:file_size, :max).to_i, locale: DataCycleCore.ui_language), locale: DataCycleCore.ui_language) if file.size > options.dig(:file_size, :max).to_i
    end

    def remove_directory
      return if self&.file&.store_dir.blank? || self&.file&.store_dir&.end_with?('/file/')
      FileUtils.remove_dir(Rails.public_path.join(file.store_dir), force: true) # deletes only EMPTY directories!
    end
  end
end
