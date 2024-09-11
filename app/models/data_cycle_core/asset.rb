# frozen_string_literal: true

# @todo: refactor after active_storage migration
# This class should not be used directly for any assets.
module DataCycleCore
  class Asset < ApplicationRecord
    attribute :type, :string, default: -> { name }
    belongs_to :creator, class_name: 'DataCycleCore::User'

    attr_accessor :binary_file_blob, :base64_file_blob
    before_validation :load_file_from_binary_file_blob, if: -> { binary_file_blob.present? }
    before_validation :load_file_from_base64_encoded_binary_file_blob, if: -> { base64_file_blob.present? }

    before_create :update_asset_attributes

    validates :file, presence: true
    validate :custom_validators
    validate :file_extension_validation

    include AssetHelpers

    has_one :asset_content, dependent: :destroy
    has_one :thing, through: :asset_content

    # @todo: disable default for audio and pdf assets
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

    DEFAULT_ASSET_VERSIONS.each do |method|
      define_method(method) do |_transformation = {}|
        file
      end
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
      new_asset.file.attach(io: File.open(file.service.path_for(file.key)), filename: file.filename, content_type: file.content_type, identify: false)
      new_asset.save
      new_asset.persisted? ? new_asset : nil
    end

    def self.extension_white_list
      []
    end

    def self.content_type_white_list
      extension_white_list.map { |extension| MiniMime.lookup_by_extension(extension)&.extension }
    end

    def file_extension_validation
      if file.present?
        extension = MiniMime.lookup_by_content_type(file.content_type.to_s)&.extension
        return if self.class.content_type_white_list.include?(extension)

        specific_mime_type = file.content_type&.then { |mt| [model_name.element, mt.split('/').last].join('/') }
        extension = MiniMime.lookup_by_content_type(specific_mime_type.to_s)&.extension
        return if self.class.content_type_white_list.include?(extension)

        extension = MiniMime.lookup_by_filename(file.record&.name.to_s)&.extension
        return if self.class.content_type_white_list.include?(extension)
      end

      errors.add :file,
                 :invalid,
                 path: 'uploader.validation.format_not_supported',
                 substitutions: {
                   data: file.content_type
                 }
    end

    def file_size_validation(options)
      return unless file.blob.byte_size > options.dig(:max).to_i
      errors.add :file,
                 :invalid,
                 path: 'uploader.validation.file_size.max',
                 substitutions: {
                   data: {
                     method: 'number_to_human_size',
                     value: options.dig(:file_size, :max).to_i
                   }
                 }
    end

    def as_json(options = {})
      if options.key?(:only)
        include_file = options[:only].delete(:file)
      else
        options[:except] ||= []
        options[:except].push(:file)
        include_file = true
      end

      hash = super(options)

      hash['file'] = { 'url' => Rails.application.routes.url_helpers.rails_storage_proxy_url(file, host: Rails.application.config.asset_host) } if include_file.present? && !file&.attachment&.blob.nil?

      hash
    end

    def warnings?
      warnings.present?
    end

    def full_warnings(locale)
      warnings
        .messages
        .map { |k, v| I18n.t("activerecord.warnings.messages.#{k}", default: k, locale:, warnings: Array.wrap(v).join(', ')) }
        .join(', ')
    end

    def warnings
      @warnings ||= ActiveModel::Errors.new(self)
    end

    private

    def metadata_from_blob
      nil
    end

    def load_file_from_remote_file_url
      return if remote_file_url.blank?

      @retry_count = 0

      begin
        if remote_file_url.starts_with?('/') && !remote_file_url.starts_with?('//')
          tmp_file = File.open(remote_file_url)
          filename = File.basename(tmp_file.path)
        else
          tmp_uri = URI.parse(Addressable::URI.parse(remote_file_url).normalize)
          tmp_file = tmp_uri.open
          filename = File.basename(tmp_uri.path)
        end
        file.attach(io: tmp_file, filename:)
      rescue StandardError => e
        raise DataCycleCore::Error::Asset::RemoteFileDownloadError, "could not download file: #{e.message}" if @retry_count >= 3

        @retry_count += 1
        sleep 5
        retry
      end
    end

    def load_file_from_binary_file_blob
      return if binary_file_blob.blank? || name.blank?

      tmp_file = Tempfile.new(name)
      File.binwrite(tmp_file, [binary_file_blob].pack('H*'))

      file.attach(io: tmp_file, filename: name)
    end

    def load_file_from_base64_encoded_binary_file_blob
      return if base64_file_blob.blank? || name.blank?

      base64_encoded = base64_file_blob.start_with?('data:') ? base64_file_blob.split(',')[1] : base64_file_blob

      decoded_data = Base64.decode64(base64_encoded)

      tmp_file = Tempfile.new(name)
      File.binwrite(tmp_file, decoded_data)

      file.attach(io: tmp_file, filename: name)
    end
  end
end
