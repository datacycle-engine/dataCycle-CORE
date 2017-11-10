module DataCycleCore
  module Api
    class ExternalSource < DataCycleCore::Generic::ImportBase

      def initialize (external_source, type, external_key)
        @external_source = external_source
        @target_type = "DataCycleCore::#{type.classify}".safe_constantize
        @external_key = external_key
      end

      protected

      def get_object_template_name(object)
        return object.try(:[], "contentType") unless object.try(:[], "contentType").blank?

        import_config = @external_source.config["import_config"].symbolize_keys
        import_config[:data_template]
      end


    end
  end
end
