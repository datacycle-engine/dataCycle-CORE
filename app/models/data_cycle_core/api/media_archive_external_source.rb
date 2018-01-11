module DataCycleCore
  module Api
    class MediaArchiveExternalSource < DataCycleCore::Api::ExternalSource
      def update(data)
        self.extend(DataCycleCore::Generic::MediaArchive::Import)
        load_transformations
        processed_items = []
        data.each do |key, object|
          template_name = get_object_template_name object
          processed_items << process_content(object, load_template(@target_type, template_name), key)
        end
        return processed_items
      end

      def create(data)
        self.update(data)
      end

      def delete(external_key)
        object = @target_type
        query = object.where(external_source: @external_source.id).where(external_key: external_key)

        if query.count(:id) == 0
          raise ActiveRecord::RecordNotFound.new("image not found")
        else
          @medium = query.first
        end

        data = @medium.get_data_hash
        if data['validity_period'].blank?
          data['validity_period'] = { 'expires' => Date.today.yesterday.to_s }
        else
          data['validity_period']['expires'] = Date.today.yesterday.to_s
        end
        @medium.set_data_hash(data_hash: data)

        if @medium.save
          return @medium
        else
          raise 'Error: Unable to update image'
        end
      end
    end
  end
end
