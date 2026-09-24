# frozen_string_literal: true

module DataCycleCore
  module OpenApi
    module Paths
      # OpenAPI 3.1 path for the v4 external-systems export endpoint
      # (config/routes.rb → `get 'external_systems/:external_system_id/things/(:ids)'`,
      # Api::V4::ExternalSystemsExportController#show):
      #   GET /external_systems/{external_system_id}/things(/{ids})
      # Grouped under the "Export" sub-group of External Sources (#50193).
      module ExternalSystemsExport
        module_function

        TAGS = ['Export'].freeze

        extend DataCycleCore::OpenApi::Localizable

        # @return [Hash{String=>Hash}] path => path item, for the paths object.
        def all
          {
            '/external_systems/{external_system_id}/things' => { 'get' => show(with_ids: false) },
            '/external_systems/{external_system_id}/things/{ids}' => { 'get' => show(with_ids: true) }
          }
        end

        # GET /external_systems/{external_system_id}/things(/{ids}) — export the
        # given (or all) things of an external system.
        def show(with_ids:)
          parameters = [Common.string_path_param('external_system_id', t('paths.external_sources.export_system_id'))]
          parameters << Common.string_path_param('ids', t('paths.external_sources.export_ids'), example: 'uuid1,uuid2') if with_ids

          Common.write_operation(
            operation_id: with_ids ? 'exportExternalSystemThingsByIds' : 'exportExternalSystemThings',
            summary: t('paths.external_sources.export_summary'),
            description: t('paths.external_sources.export_description'),
            tags: TAGS,
            parameters:,
            responses: { '200' => Common.json_object_response(t('paths.external_sources.export_response'), schema: export_result) }.merge(Common.error_responses)
          )
        end

        # Export body. The concrete shape (and even the media type) is defined by
        # the external system's configured transformation class
        # (ExternalSystemsExportController#show renders `transformations.render`),
        # so it is an open object rather than a fixed schema.
        def export_result
          {
            'type' => 'object',
            'title' => 'ExportResult',
            'additionalProperties' => true
          }
        end
      end
    end
  end
end
