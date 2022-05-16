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

            data.each do |item|
              next if item.try(:asset)&.file&.file&.path.blank?

              ftp.putbinaryfile(item.asset.file.file.path, item.id + File.extname(item.asset.file.file.path))
            end
          end
        end

        private

        def create_folder_path(ftp, path)
          created_path = ['/']

          path&.split('/')&.each do |folder|
            current_path = File.join(created_path)
            new_path = File.join(created_path.push(folder))
            ftp.mkdir(new_path) if folder.present? && !ftp.list(current_path).any? { |dir| dir.match(/\s#{folder}$/) }
          end
        end
      end
    end
  end
end
