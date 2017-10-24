class DataCycleCore::Generic::DownloadStrategy::EndpointEyebase
  def initialize(host: nil, end_point: nil, token: nil)
    @host = host
    @end_point = end_point
    @token = token
  end


  def media_assets(lang: :de)
    Enumerator.new do |yielder|
      load_folders.xpath('//folder/id').map(&:text).map(&:to_i).sort.reverse.each do |folder_id|
        doc = load_assets(folder_id)

        doc.xpath('//mediaasset').map(&:to_hash).each do |raw_asset_data|
          next if raw_asset_data['mediaassettype'] != '501'

          raise "Missing image file" if raw_asset_data['quality_1'].nil?
          full_image_path = File.join(Rails.public_path, 'eyebase', 'media_assets', 'files', raw_asset_data['quality_1']['filename'])
          FileUtils.mkdir_p(File.dirname(full_image_path))
          File.open(full_image_path, 'wb') do |local_file|
            open(raw_asset_data['quality_1']['url'], 'rb') do |remote_file|
              local_file.write(remote_file.read)
            end
          end

          raise "Missing thumbnail file" if raw_asset_data['quality_512'].nil?
          thumbnail_path = File.join(Rails.public_path, 'eyebase', 'media_assets', 'files', raw_asset_data['quality_512']['filename'])
          FileUtils.mkdir_p(File.dirname(thumbnail_path))
          File.open(thumbnail_path, 'wb') do |local_file|
            open(raw_asset_data['quality_512']['url'], 'rb') do |remote_file|
              local_file.write(remote_file.read)
            end
          end

          yielder << raw_asset_data
        end
      end
    end
  end

  protected

  def load_folders
    load(qt: 'ftree')
  end

  def load_languages
    load(qt: 'lang')
  end

  def load_asset_types
    load(qt: 'mat')
  end

  def load_assets(folder_id)
    load(qt: 'r', keyfolder: folder_id)
  end

  def load(**parameters)
    default_parameters = {
      fx: 'api',
      token: @token
    }

    Nokogiri::XML(open("#{File.join(@host, @end_point)}?#{default_parameters.merge(parameters).to_query}"))
  end
end
