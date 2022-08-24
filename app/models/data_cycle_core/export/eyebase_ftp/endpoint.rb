# frozen_string_literal: true

module DataCycleCore
  module Export
    module EyebaseFtp
      class Endpoint < DataCycleCore::Export::Generic::Endpoint
        require 'net/ftp'

        def initialize(**options)
          @user = options.dig(:user)
          @password = options.dig(:password)
          @host = options.dig(:host)
        end

        def content_request(utility_object:, data:)
          path = utility_object.external_system.export_config[:path]

          Net::FTP.open(@host, @user, @password) do |ftp|
            if path.present?
              create_folder_path(ftp, path) if path.present?
              ftp.chdir(path)
            end

            Array.wrap(data).each do |item|
              if item.try(:asset)&.class&.active_storage_activated? && item.try(:asset)&.file&.attached?
                asset_path = item.asset.file.service.path_for(item.asset.file.key)
                next if asset_path.blank?
                file_ext = item.asset.file.filename.extension_with_delimiter
              else
                asset_path = item.try(:asset)&.file&.file&.path
                next if asset_path.blank?
                file_ext = File.extname(asset_path)
              end

              ftp.putbinaryfile(asset_path, item.id + file_ext)
            end
          end
        end

        private

        def create_folder_path(ftp, path)
          created_path = ['/']

          path&.split('/')&.each do |folder|
            current_path = File.join(created_path)
            new_path = File.join(created_path.push(folder))
            ftp.mkdir(new_path) if folder.present? && ftp.list(current_path).none? { |dir| dir.match(/\s#{folder}$/) }
          end
        end
      end
    end
  end
end
