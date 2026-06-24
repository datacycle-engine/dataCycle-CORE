# frozen_string_literal: true

require 'open-uri'
require 'resolv'
require 'ipaddr'

# @todo: refactor after active_storage migration
# This class should not be used directly for any assets.
module DataCycleCore
  class Asset < ApplicationRecord
    attribute :type, :string, default: -> { name }
    belongs_to :creator, class_name: 'DataCycleCore::User'

    attr_accessor :binary_file_blob, :base64_file_blob, :remote_file_url

    before_validation :load_file_from_binary_file_blob, if: -> { binary_file_blob.present? }
    before_validation :load_file_from_base64_encoded_binary_file_blob, if: -> { base64_file_blob.present? }
    before_validation :load_file_from_remote_file_url, if: -> { remote_file_url.present? }

    before_create :update_asset_attributes

    validates :file, presence: true
    validate :file_extension_validation
    validate :content_type_validation
    validate :custom_validators

    include AssetHelpers
    include DataCycleCore::Common::Routing

    has_one :asset_content, dependent: :destroy
    has_one :thing, through: :asset_content

    # @todo: disable default for audio and pdf assets
    DEFAULT_ASSET_VERSIONS = [:original, :default].freeze

    # SSRF protection for remote_file_url downloads (see security finding DC-16).
    ALLOWED_REMOTE_SCHEMES = ['http', 'https'].freeze
    MAX_REMOTE_REDIRECTS = 5
    # Loopback, private, link-local (incl. cloud metadata 169.254.169.254),
    # shared/CGN, reserved and multicast ranges that must never be fetched.
    BLOCKED_IP_RANGES = [
      '0.0.0.0/8', '10.0.0.0/8', '100.64.0.0/10', '127.0.0.0/8',
      '169.254.0.0/16', '172.16.0.0/12', '192.0.0.0/24', '192.168.0.0/16',
      '198.18.0.0/15', '224.0.0.0/4', '240.0.0.0/4',
      '::1/128', 'fc00::/7', 'fe80::/10', 'ff00::/8'
    ].map { |range| IPAddr.new(range) }.freeze

    def custom_validators
      DataCycleCore.uploader_validations[self.class.name.demodulize.underscore]&.except(:format)&.presence&.each do |validator, options|
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

    def self.normalized_extension_white_list
      extension_white_list.filter_map { |extension| MiniMime.lookup_by_extension(extension)&.extension }.uniq
    end

    def self.content_type_white_list
      extension_white_list.filter_map { |extension| MiniMime.lookup_by_extension(extension)&.content_type }.uniq
    end

    def filename_without_extension
      filename = (thing&.title.presence || name.presence || file.filename.to_s).to_slug
      filename.delete_suffix("-#{file_extension}").delete_suffix(".#{file_extension}")
    end

    def filename
      "#{filename_without_extension}.#{file_extension}"
    end

    def content_url
      return unless file.attached?

      local_blob_url(id: file.blob.id, file: filename)
    end

    def file_extension
      return @file_extension if defined? @file_extension
      return @file_extension = nil if file.blank?

      @file_extension = MiniMime.lookup_by_content_type(file.content_type.to_s)&.extension
    end

    def file_extension_validation
      if file.present?
        return if self.class.normalized_extension_white_list.include?(file_extension)

        specific_mime_type = file.content_type&.then { |mt| [model_name.element, mt.split('/').last].join('/') }
        extension = MiniMime.lookup_by_content_type(specific_mime_type.to_s)&.extension
        return if self.class.normalized_extension_white_list.include?(extension)

        extension = MiniMime.lookup_by_filename(file.record&.name.to_s)&.extension
        return if self.class.normalized_extension_white_list.include?(extension)
      end

      errors.add :file,
                 :invalid,
                 path: 'uploader.validation.format_not_supported',
                 substitutions: {
                   data: extension
                 }
    end

    def content_type_validation
      return if file.present? && self.class.content_type_white_list.include?(file.content_type)

      errors.add(:file,
                 :invalid,
                 path: 'uploader.validation.content_type_not_supported',
                 substitutions: {
                   data: file.content_type
                 })
    end

    def file_size_validation(options)
      return unless file.blob.byte_size > options[:max].to_i

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

      hash = super

      hash['file'] = { 'url' => content_url } if include_file.present?

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

    def full_errors(locale)
      errors
        .map { |e|
          e.options.present? ? "#{self.class.human_attribute_name(e.attribute, locale: locale)} #{DataCycleCore::LocalizationService.translate_and_substitute(e.options, locale)}" : I18n.with_locale(locale) { e.message }
        }
        .flatten
        .join(', ')
    end

    def warnings
      @warnings ||= ActiveModel::Errors.new(self)
    end

    private

    def metadata_from_blob
      nil
    end

    def allowed_local_import_path?(path)
      candidate_path = File.realpath(path)
      base_path = Rails.root.join('private', 'import').realpath.to_s

      candidate_path.start_with?(base_path)
    rescue Errno::ENOENT
      false
    end

    # Fetches a remote URL with SSRF protection: validates every hop against a
    # private/loopback/link-local IP denylist and follows redirects manually so
    # a public host cannot redirect (or DNS-rebind) into an internal address.
    def download_remote_file(url, redirects_left = MAX_REMOTE_REDIRECTS)
      uri = normalized_remote_uri(url)
      validate_remote_file_uri!(uri)
      uri.open(redirect: false)
    rescue OpenURI::HTTPRedirect => e
      raise DataCycleCore::Error::Asset::RemoteFileDownloadError, "too many redirects for: #{url}" if redirects_left <= 0

      download_remote_file(e.uri.to_s, redirects_left - 1)
    end

    def normalized_remote_uri(url)
      URI.parse(Addressable::URI.parse(url).normalize.to_s)
    end

    def validate_remote_file_uri!(uri)
      raise DataCycleCore::Error::Asset::RemoteFileDownloadError, "scheme not allowed: #{uri.scheme}" unless ALLOWED_REMOTE_SCHEMES.include?(uri.scheme)
      raise DataCycleCore::Error::Asset::RemoteFileDownloadError, "host missing: #{uri}" if uri.host.blank?

      addresses = Resolv.getaddresses(uri.host)
      raise DataCycleCore::Error::Asset::RemoteFileDownloadError, "host not resolvable: #{uri.host}" if addresses.blank?

      addresses.each do |address|
        ip = IPAddr.new(address)
        raise DataCycleCore::Error::Asset::RemoteFileDownloadError, "blocked address for host #{uri.host}: #{address}" if BLOCKED_IP_RANGES.any? { |range| range.include?(ip) }
      rescue IPAddr::InvalidAddressError
        next
      end
    end

    def load_file_from_remote_file_url
      return if remote_file_url.blank?

      @retry_count = 0

      begin
        if remote_file_url.starts_with?('/') && !remote_file_url.starts_with?('//')
          raise DataCycleCore::Error::Asset::RemoteFileDownloadError, "local file path not allowed: #{remote_file_url}" unless allowed_local_import_path?(remote_file_url)

          tmp_file = File.open(remote_file_url) # rubocop:disable Style/FileOpen
          filename = File.basename(tmp_file.path)
        else
          tmp_file = download_remote_file(remote_file_url)
          filename = File.basename(normalized_remote_uri(remote_file_url).path)
        end

        file.attach(io: tmp_file, filename:)
      rescue DataCycleCore::Error::Asset::RemoteFileDownloadError
        raise
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
