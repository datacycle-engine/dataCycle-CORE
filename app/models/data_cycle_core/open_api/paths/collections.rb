# frozen_string_literal: true

module DataCycleCore
  module OpenApi
    module Paths
      # OpenAPI 3.1 paths for the v4 collection (watch list) endpoints
      # (config/routes.rb → watch_lists controller):
      #   /collections                              (index)
      #   /collections/create                       (create)
      #   /collections/:id                          (show — redirects to contents)
      #   /collections/:id/add_item(/:thing_id)     (add_item)
      #   /collections/:id/remove_item(/:thing_id)  (remove_item)
      #   /collections/:id/download_and_reset       (download_and_reset)
      # Read operations are GET+POST; the management operations use their real
      # HTTP methods (#50193).
      module Collections
        module_function

        TAGS = ['Collections'].freeze

        extend DataCycleCore::OpenApi::Localizable

        # @return [Hash{String=>Hash}] path => path item, for the paths object.
        def all
          {
            '/collections' => collections,
            '/collections/create' => { 'post' => create_collection },
            '/collections/{id}' => collection,
            '/collections/{id}/add_item' => { 'post' => add_item(with_thing_id: false) },
            '/collections/{id}/add_item/{thing_id}' => { 'post' => add_item(with_thing_id: true) },
            '/collections/{id}/remove_item' => { 'post' => remove_item(with_thing_id: false) },
            '/collections/{id}/remove_item/{thing_id}' => { 'post' => remove_item(with_thing_id: true) },
            '/collections/{id}/download_and_reset' => { 'get' => download_and_reset }
          }
        end

        # GET/POST /collections — list of accessible collections.
        def collections
          Common.read_path_item(
            operation_id: 'Collections',
            summary: t('paths.collections.collections_summary'),
            tags: TAGS,
            parameters: Common.list_parameters(with_filter: false),
            responses: {
              '200' => Common.envelope_response(t('paths.collections.collections_response'))
            }.merge(Common.error_responses)
          )
        end

        # GET/POST /collections/{id} — redirects to the collection's content listing.
        def collection
          op = {
            'summary' => t('paths.collections.collection_summary'),
            'description' => t('paths.collections.collection_description'),
            'tags' => TAGS,
            'parameters' => [Common.id_path_param('id', t('paths.collections.collection_id'))],
            # Common.redirect_response rather than an own 302 object: the Location-header shape
            # was spelled out a second time here, although Contents#universal and
            # ExternalSources#key_item already build the same response from the shared block.
            'responses' => { '302' => Common.redirect_response(t('paths.collections.collection_redirect')) }.merge(Common.error_responses)
          }
          {
            'get' => op.merge('operationId' => 'getCollection'),
            'post' => op.merge('operationId' => 'postCollection')
          }
        end

        # POST /collections/create — create a new (download) collection, optionally
        # pre-filled with the given content ids. Requires the :create ability on
        # WatchList. Renders { id, name } with HTTP 200.
        def create_collection
          Common.write_operation(
            operation_id: 'createCollection',
            summary: t('paths.collections.create_summary'),
            description: t('paths.collections.create_description'),
            tags: TAGS,
            request_body: Common.json_request_body(create_request, required: false),
            responses: { '200' => Common.json_response(t('paths.collections.create_response'), collection_stub) }.merge(Common.write_error_responses)
          )
        end

        # POST /collections/{id}/add_item(/{thing_id}) — add a content to the
        # collection. Requires the :add_item ability. The content id is taken from
        # the path (when present) or the request body.
        def add_item(with_thing_id:)
          item_operation('addItemToCollection', t('paths.collections.add_item_summary'), t('paths.collections.add_item_response'), with_thing_id:)
        end

        # POST /collections/{id}/remove_item(/{thing_id}) — remove a content from
        # the collection. Requires the :remove_item ability.
        def remove_item(with_thing_id:)
          item_operation('removeItemFromCollection', t('paths.collections.remove_item_summary'), t('paths.collections.remove_item_response'), with_thing_id:)
        end

        # GET /collections/{id}/download_and_reset — download the collection's
        # contents as a file and reset (empty) the collection.
        # NOTE: the route (watch_lists#download_and_reset) exists in config/routes.rb
        # but no controller action or view was found in the codebase at the time of
        # writing (#50193). Documented per ticket scope; verify the real behaviour
        # and response shape before clients rely on it.
        def download_and_reset
          Common.write_operation(
            operation_id: 'downloadAndResetCollection',
            summary: t('paths.collections.download_and_reset_summary'),
            description: t('paths.collections.download_and_reset_description'),
            tags: TAGS,
            parameters: [Common.id_path_param('id', t('paths.collections.collection_id'))],
            responses: { '200' => Common.file_response(t('paths.collections.download_and_reset_response')) }.merge(Common.error_responses)
          )
        end

        # Shared builder for add_item/remove_item (they differ only in id/summary).
        def item_operation(operation_id, summary, response_description, with_thing_id:)
          parameters = [Common.id_path_param('id', t('paths.collections.collection_id'))]
          parameters << Common.id_path_param('thing_id', t('paths.collections.item_thing_id')) if with_thing_id
          Common.write_operation(
            operation_id: with_thing_id ? "#{operation_id}ByPath" : operation_id,
            summary:,
            tags: TAGS,
            parameters:,
            request_body: with_thing_id ? nil : Common.json_request_body(item_request),
            responses: { '204' => Common.no_content_response(response_description) }.merge(Common.write_error_responses)
          )
        end

        # Request body of POST /collections/create.
        def create_request
          {
            'type' => 'object',
            'title' => 'CollectionCreateRequest',
            'properties' => {
              'thing_id' => {
                'description' => t('paths.collections.create_thing_id'),
                'oneOf' => [
                  { 'type' => 'string', 'format' => 'uuid' },
                  { 'type' => 'array', 'items' => { 'type' => 'string', 'format' => 'uuid' } }
                ]
              }
            }
          }
        end

        # Request body of add_item/remove_item without a {thing_id} path segment.
        def item_request
          {
            'type' => 'object',
            'title' => 'CollectionItemRequest',
            'properties' => {
              'thing_id' => { 'type' => 'string', 'format' => 'uuid', 'description' => t('paths.collections.item_thing_id') }
            },
            'required' => ['thing_id']
          }
        end

        # 200 body of POST /collections/create ({ id, name }).
        def collection_stub
          {
            'type' => 'object',
            'title' => 'CollectionStub',
            'properties' => {
              'id' => { 'type' => 'string', 'format' => 'uuid' },
              'name' => { 'type' => 'string' }
            }
          }
        end
      end
    end
  end
end
