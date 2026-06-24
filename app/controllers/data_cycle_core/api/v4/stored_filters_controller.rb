# frozen_string_literal: true

module DataCycleCore
  module Api
    module V4
      class StoredFiltersController < ::DataCycleCore::Api::V4::ContentsController
        VALIDATE_PARAMS_CONTRACT = MasterData::Contracts::ApiCollectionContract

        def create
          @collection = DataCycleCore::Collection.by_id_or_slug(permitted_params[:endpoint]).first!
          @stored_filter = @collection if @collection.is_a?(DataCycleCore::StoredFilter)
          @watch_list = @collection if @collection.is_a?(DataCycleCore::WatchList)
          @classification_trees_parameters |= Array.wrap(@collection.classification_tree_labels)
          @type = permitted_params.dig(:collection, :@type) || WatchList::API_V4_TYPE

          if @type == WatchList::API_V4_TYPE
            @new_collection = DataCycleCore::WatchList.create(
              full_path: permitted_params.dig(:collection, :name) || "#{@collection.name.presence || 'Temp Collection'} - #{Time.current.iso8601}",
              classification_tree_labels: @classification_trees_parameters,
              linked_stored_filter_id: @collection.linked_stored_filter_id,
              manual_order: true,
              api: true,
              shared_users: [current_user]
            )
            raise(Error::BadRequestError, I18n.with_locale(:en) { @new_collection.errors.messages.values.flatten.map { |m| { path: ['collection'], message: m } } }) unless @new_collection.persisted?

            query = build_search_query
            @new_collection.add_things_from_query(query.query)
          elsif @type == StoredFilter::API_V4_TYPE
            # [TODO] create stored_filter, implement parameters transformation for APIv4 filters
            # @new_collection = @collection.to_stored_filter
            # @new_collection.classification_tree_labels = @classification_trees_parameters
            # @new_collection.apply_sorting_from_api_parameters(permitted_params.to_h)
            # @new_collection.parameters += Array.wrap(permitted_params[:filter].to_h)
            # @new_collection.save!
          end

          # has no effect at the moment, as the default permissions are not as strict as they should be
          # data_link = DataCycleCore::DataLink.create(
          #   creator: current_user,
          #   receiver: current_user,
          #   item: @new_collection,
          #   permissions: DataLink::PERMISSIONS[:read],
          #   valid_from: permitted_params.dig(:collection, :validFrom),
          #   valid_until: permitted_params.dig(:collection, :validUntil)
          # )
          # raise(Error::BadRequestError, I18n.with_locale(:en) { data_link.errors.messages.values.flatten.map { |m| { path: ['collection'], message: m } } }) unless data_link.persisted?

          json = {}
          json['@context'] = ApiRenderer::ThingRendererV4.api_plain_context(@language, @expand_language) unless @section_parameters[:@context]&.to_i&.zero?
          json['@graph'] = [@new_collection.to_api_v4_json]

          render json:, status: :created
        end

        private

        def permitted_parameter_keys
          super + [:endpoint, { collection: [:@type, :name, :validFrom, :validUntil] }]
        end
      end
    end
  end
end
