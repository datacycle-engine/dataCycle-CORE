# frozen_string_literal: true

module DataCycleCore
  module DownloadHandler
    extend ActiveSupport::Concern

    def download_single(content)
      mime_type = content.asset.file.content_type
      file_extension = Rack::Mime::MIME_TYPES.invert[mime_type]
      download_file = content.asset.file.path

      send_file download_file, filename: "#{content.title.blank? ? 'unkown_title' : content.title.parameterize(separator: '_')}#{file_extension}", disposition: 'attachment', type: mime_type
    end

    def download_zip(collection, items)
      download_dir = Rails.root.join('public', 'downloads')

      Dir.mkdir(download_dir) unless File.exist?(download_dir)

      cleanup_files(download_dir)

      zipfile_name = "#{collection.id}-#{Time.now.to_i}.zip"
      zipfile_fullname = File.join(download_dir, zipfile_name)

      unless File.exist?(zipfile_fullname)
        Zip::File.open(zipfile_fullname, Zip::File::CREATE) do |zipfile|
          items.each do |content|
            mime_type = content.asset.file.content_type
            file_extension = Rack::Mime::MIME_TYPES.invert[mime_type]
            zipfile.add("#{content.title.blank? ? File.basename(content.asset.file.path) : content.title.parameterize(separator: '_')}#{file_extension}", content.asset.file.path)
          end
        end
      end

      send_file zipfile_fullname, filename: zipfile_name, disposition: 'attachment', type: 'application/zip'
    end

    # remove all files older than 2 hours
    def cleanup_files(dir)
      max_age = 2
      pattern = '*.zip'
      logger.info "DataCycleCore::DownloadHanlder: directory does not exist: #{dir}" unless File.directory?(dir)

      Dir.glob(File.join(File.expand_path(dir), pattern)).each do |file_name|
        File.delete(file_name) if ((Time.zone.now - File.ctime(file_name)) / 1.hour) > max_age
      end
    end
  end
end
