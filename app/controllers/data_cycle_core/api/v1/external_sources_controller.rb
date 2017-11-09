module DataCycleCore
  class Api::V1::ExternalSourcesController < Api::V1::ApiBaseController

    def update
      content = params[:content]
      raise content.inspect
      content = external_sources_params[:content]
      raise content.inspect
      @content = Object.const_get("DataCycleCore::#{params[:type].classify}")
        .includes({classifications: [], translations: []})
        .find(params[:id])

      render json: @content.get_data_hash

    end

    def destroy

      @content = Object.const_get("DataCycleCore::#{params[:type].classify}")
        .includes({classifications: [], translations: []})
        .find(params[:id])

      # @content.destroy
      # render json: {"success" => @content.destroyed?}

    end

    def test
      raise nil.inspect

      render json: {'juhu' => 'NOPE'}
    end

    def test_old

      external_source = image_params.dig('external_source')
      external_key = image_params.dig('external_key')

      raise 'Error: Unable to delete image' if external_key.blank? || external_source.blank?

      #get correct key
      external_key = 'http://localhost:3001/api/v1/media/3'
      query = DataCycleCore::CreativeWork.where(external_source: external_source).where(external_key: external_key)

      if query.count(:id) == 0
        raise ActiveRecord::RecordNotFound.new("image not found")
      else
        @image = query.first
      end

      data = @image.get_data_hash
      if data['validity_period'].blank?
        data['validity_period'] = { 'expires' => Date.today.yesterday.to_s }
      else
        data['validity_period']['expires'] = Date.today.yesterday.to_s
      end
      @image.set_data_hash(data_hash: data)

      if @image.save
        render json: { "success" => @image.get_data_hash }
      else
        raise 'Error: Unable to update image'
      end

    end

    private

    def external_sources_params
      params.permit(:external_source_id, :type, :external_key, :token)
    end

  end
end
