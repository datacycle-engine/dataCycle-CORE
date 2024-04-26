# frozen_string_literal: true

DataCycleCore::Engine.routes.draw do
  devise_for :users, class_name: 'DataCycleCore::User', module: :devise,
                     controllers: {
                       passwords: 'data_cycle_core/passwords',
                       sessions: 'data_cycle_core/sessions',
                       registrations: 'data_cycle_core/registrations',
                       confirmations: 'data_cycle_core/confirmations',
                       omniauth_callbacks: 'data_cycle_core/omniauth'
                     }

  authenticated :user do
    root 'backend#index', as: :authenticated_root
  end

  authenticate do
    post '/', to: 'backend#index'
    get  '/settings', to: 'backend#settings'
  end

  match '/401', to: 'exceptions#unauthorized_exception', via: :all, as: :unauthorized_exception
  match '/404', to: 'exceptions#not_found_exception', via: :all, as: :not_found_exception
  match '/409', to: 'exceptions#conflict_exception', via: :all, as: :conflict_exception
  match '/422', to: 'exceptions#unprocessable_entity_exception', via: :all, as: :unprocessable_entity_exception
  match '/500', to: 'exceptions#internal_server_error_exception', via: :all, as: :internal_server_error_exception

  CONTENT_TABLES_FALLBACK ||= ['organizations', 'persons', 'events', 'places', 'products', 'media_objects', 'creative_works'].freeze
  CONTENT_TABLE ||= ['things'].freeze

  root to: redirect('users/sign_in')

  scope module: 'static', path: 'docs', as: :docs, defaults: { root_path: 'docs' } do
    get '/', action: :show
    get '/*path/:file', action: :image, constraints: ->(request) { request.path.match?(/\.(gif|jpg|png|svg)$/) }
    get '/*path', action: :show, as: :with
  end

  scope module: 'static', path: 'static', as: :static, defaults: { root_path: 'static' } do
    get '/*path/:file', action: :image, constraints: ->(request) { request.path.match?(/\.(gif|jpg|png|svg)$/) }
    get '/*path', action: :show, as: :with
  end

  get '/assets/:klass/:id/:version(/:file)', to: 'missing_asset#show', as: 'local_asset', constraints: {
    klass: /(image|audio|video|pdf|text_file|data_cycle_file|srt_file)/,
    id: /[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}/,
    file: /.*/
  }
  get '/processed/:klass/:id(/:file)', to: 'missing_asset#processed', constraints: {
    klass: /(image|audio|video|pdf|text_file|data_cycle_file|srt_file)/,
    id: /[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}/
  }

  get '/schema', to: 'schema#index'
  get '/schema/:id', to: 'schema#show', as: :schema_details
  get '/info', to: 'frontend#info', as: :info
  get '/i18n/translate', to: 'application#translate'

  authenticate do
    get :clear_all_caches, controller: :application

    resources :users, only: [:index, :show, :edit, :update, :destroy] do
      delete :lock, on: :member
      post :unlock, on: :member
      post :confirm, on: :member
      post :create_user, on: :collection
      get :search, on: :collection
      post :validate, on: :member
      post :validate, on: :collection
      get :consent, on: :collection
      post :update_consent, on: :collection
      get :become
      match '/index', via: [:get, :post], on: :collection, action: :index
      post :download_user_info_activity, on: :collection
    end

    resources :permissions, only: [:index]

    resources :user_groups, only: [:index, :edit, :update, :destroy] do
      post '/create', on: :collection, action: :create
      post '/', on: :collection, action: :index
    end

    scope '(/watch_lists/:watch_list_id)', defaults: { watch_list_id: nil } do
      resources(*(CONTENT_TABLES_FALLBACK + CONTENT_TABLE).map(&:to_sym), controller: :things) do
        post :import, on: :collection
        get 'history/:history_id', action: :history, on: :member, as: :history
        post 'history/:history_id/restore_version', action: :restore_history_version, on: :member, as: :restore_history_version
        get 'external/:external_system_id/:external_key/edit', action: 'edit_by_external_key', on: :collection
        post :load_more_linked_objects, on: :member
        get :load_more_related, on: :member
        get :load_more_duplicates, on: :member
        get 'download/(:serialize_format)', on: :member, as: 'download', to: '/data_cycle_core/downloads#download_thing'
        get :download_zip, on: :member, to: '/data_cycle_core/downloads#download_thing_zip'
        get :download_indesign, on: :member, to: '/data_cycle_core/downloads#download_thing_indesign'
        get :create_duplication, on: :member
        get :clear_cache, on: :member
        get :destroy_auto_translate, on: :member
        post :validate, on: :member
        match :geojson_for_map_editor, on: :collection, via: [:get, :post], defaults: { format: 'application/vnd.geo+json' }
        post :validate, on: :collection
        get :compare, on: :collection
        get :select_search, on: :collection
        post :render_embedded_object, on: :member
        post :bulk_create, on: :collection
        delete :remove_locks, on: :member
        get 'split_view/:source_id', on: :member, action: :split_view, as: 'split_view'
        post :attribute_value, on: :member
        post :attribute_default_value, on: :collection, defaults: { format: 'application/json' }
        post :switch_primary_external_system, on: :member
        post :demote_primary_external_system, on: :member
        post :content_score, on: :collection
        post :create_external_connection, on: :member
        post :elevation_profile, on: :member
        delete :remove_external_connection, on: :member
        post '/', on: :member, action: :show
      end
    end
  end

  scope '(/watch_lists/:watch_list_id)', defaults: { watch_list_id: nil } do
    resources(*(CONTENT_TABLES_FALLBACK + CONTENT_TABLE).map(&:to_sym), controller: :things, only: []) do
      get 'asset/:type', on: :member, action: :asset, constraints: { type: /(content|thumb|original)/ }
    end
  end

  authenticate do
    resources :subscriptions, only: [:index, :destroy] do
      post '/create', on: :collection, action: :create
      post '/', on: :collection, action: :index
    end

    resources :stored_filters, only: [:index, :show, :create, :destroy], path: :search_history do
      get :search, on: :collection
      get :select_search_or_collection, on: :collection
      get :download_zip, on: :member, to: '/data_cycle_core/downloads#download_stored_filter_zip'
      get 'download/(:serialize_format)', on: :member, to: '/data_cycle_core/downloads#download_stored_filter', as: 'download'
      post :add_to_watchlist, on: :collection
      get :saved_searches, on: :collection
      get :render_update_form, on: :collection
    end

    defaults format: :json do
      resource :content_locks, only: :update do
        post :destroy, on: :collection
      end
    end

    scope('files') do
      resources :assets, only: [:index, :create, :update, :destroy] do
        get :find, on: :collection
        post :duplicate, on: :member
        delete :delete, action: 'destroy_multiple', on: :collection
        delete :delete_all, action: 'destroy_all', on: :collection
      end
    end

    resource :downloads, only: [] do
      get '/things(/:id)(/:serialize_format)(/:version)', on: :member, action: 'things', as: 'things'
      get '/thing_collections(/:id)', on: :member, action: 'thing_collections', as: 'thing_collections'
      get '/watch_lists(/:id)(/:serialize_format)', on: :member, action: 'watch_lists', as: 'watch_lists'
      get '/watch_list_collections(/:id)', on: :member, action: 'watch_list_collections', as: 'watch_list_collections'
      get '/stored_filters(/:id)(/:serialize_format)', on: :member, action: 'stored_filters', as: 'stored_filters'
      get '/stored_filter_collections(/:id)', on: :member, action: 'stored_filter_collections', as: 'stored_filter_collections'
    end

    resources :data_links, except: [:show] do
      post :send_mail, on: :member
      patch :unlock, on: :member
      get :render_update_form, on: :collection
    end
  end

  resources :data_links, only: [:show] do
    match :download, on: :member, to: '/data_cycle_core/downloads#download_data_link', via: [:get, :post]
    get :get_text_file, on: :member
  end

  authenticate do
    resources :watch_lists do
      delete :remove_item, on: :member
      get :add_item, on: :member
      post :add_related_items, on: :collection
      get :bulk_edit, on: :member
      patch :bulk_update, on: :member
      post :validate, on: :member
      get :download_zip, on: :member, to: '/data_cycle_core/downloads#download_watch_list_zip'
      get :download_indesign, on: :member, to: '/data_cycle_core/downloads#download_watch_list_indesign'
      get 'download/(:serialize_format)', on: :member, to: '/data_cycle_core/downloads#download_watch_list', as: 'download'
      delete :bulk_delete, on: :member
      delete :clear, on: :member
      get :search, on: :collection
      patch :update_order, on: :member
      post '/', on: :member, action: :show
    end

    resources :classifications, only: [:index, :create] do
      put :update, on: :collection
      patch :update, on: :collection
      delete :destroy, on: :collection
      get :search, on: :collection
      get :find, on: :collection
      get :download, on: :collection
      patch :move, on: :collection
      patch :merge, on: :collection
    end
  end

  scope :admin do
    resources :external_systems, only: [] do
      get :authorize, on: :member
      get :callback, on: :member
    end
  end

  resources :external_systems, only: [:index]

  authenticate do
    resources :external_systems, only: [:create] do
      get :render_new_form, on: :collection
    end

    resources :schedules, only: [] do
      get :load_more, on: :member
    end

    namespace :dash_board, path: '/admin', as: :admin do
      get '/', action: :home, as: ''
      get '/download/:id', action: :download, as: :download
      get '/download_full/:id', action: :download_full, as: :download_full
      get '/download_import/:id', action: :download_import, as: :download_import
      get '/import/:id', action: :import, as: :import
      get '/import_full/:id', action: :import_full, as: :import_full
      get '/delete_queue/:id', action: :delete_queue, as: :delete_queue
      get :activities
      get '/activity_details/:type', action: :activity_details, as: :activity_details, defaults: { format: :json }

      scope :maintenance do
        get :rebuild_classification_mappings
      end
    end

    get '/reports', to: 'reports#index'
    match '/download_reports', to: 'reports#download_report', via: [:get, :post]

    if DataCycleCore.main_config.dig(:api, :enabled)
      defaults format: :json do
        namespace :api do
          if DataCycleCore.main_config.dig(:api, :v1, :enabled)
            namespace :v1 do
              resources :stored_filters, only: [:show], path: :endpoints

              resources :classification_trees, only: [:index, :show] do
                get :classifications, on: :member
              end

              resources :collections, only: [:index, :show], controller: :watch_lists

              # TODO: refactor with new API implementation
              resources :events, only: [:index, :show]

              # type_regexp = Regexp.new(*DataCycleCore.content_tables.map(&:to_sym).join('|'))
              resources :contents, path: ':type', constraints: { type: /things/ }, only: [:show] do
                get :search, on: :collection
                patch :update, on: :member
              end

              get 'contents/search', to: 'contents#search'
              get 'contents/deleted', to: 'contents#deleted'

              scope 'external_sources/:external_source_id' do
                resource :things, only: [:show, :create, :update, :destroy], controller: :external_systems, path: ':type/:external_key', constraints: { type: /creative_work/ }
              end
            end
          end
          if DataCycleCore.main_config.dig(:api, :v2, :enabled)
            namespace :v2 do
              scope path: '(/:api_subversion)' do
                type_regexp = Regexp.new(*CONTENT_TABLES_FALLBACK.map(&:to_sym).join('|'))
                get 'endpoints/:id(/:type)', to: 'contents#index', constraints: { type: type_regexp }, as: 'stored_filter'

                resources(*(CONTENT_TABLES_FALLBACK + CONTENT_TABLE).map(&:to_sym), only: [:index, :show]) do
                  get :gpx, on: :member, to: '/data_cycle_core/downloads#download_gpx'
                end

                get 'contents/search(/:type)', to: 'contents#index', constraints: { type: type_regexp }, as: 'contents_search'
                get 'contents/deleted(/:type)', to: 'contents#deleted', constraints: { type: type_regexp }, as: 'contents_deleted'

                resources :classification_trees, only: [:index, :show] do
                  get :classifications, on: :member
                end

                resources :collections, only: [:index, :show], controller: :watch_lists

                scope 'external_sources/:external_source_id' do
                  resource :things, only: [:create, :update, :destroy], controller: :external_systems, path: ':type/:external_key', constraints: { type: /creative_work/ }
                end

                resources :external_systems, only: [:show], controller: :external_systems
              end
            end
          end
          if DataCycleCore.main_config.dig(:api, :v3, :enabled)
            namespace :v3 do
              scope path: '(/:api_subversion)' do
                type_regexp = Regexp.new(*CONTENT_TABLES_FALLBACK.map(&:to_sym).join('|'))
                match 'endpoints/:id(/:type)(/:content_id)', to: 'contents#index', constraints: { type: type_regexp }, as: 'stored_filter', via: [:get, :post]

                resources(*(CONTENT_TABLES_FALLBACK + CONTENT_TABLE).map(&:to_sym), only: []) do
                  get :gpx, on: :member, to: '/data_cycle_core/downloads#download_gpx'
                end

                (CONTENT_TABLES_FALLBACK + CONTENT_TABLE).each do |content_type|
                  match content_type, to: "#{content_type}#index", as: content_type, via: [:get, :post]
                  match "#{content_type}/:id", to: "#{content_type}#show", as: content_type.singularize, via: [:get, :post]
                end

                match 'contents/search(/:type)', to: 'contents#index', constraints: { type: type_regexp }, as: 'contents_search', via: [:get, :post]
                match 'contents/deleted(/:type)', to: 'contents#deleted', constraints: { type: type_regexp }, as: 'contents_deleted', via: [:get, :post]

                get 'authorize/download_token', to: 'contents#download_token'

                resources :classification_trees, only: [] do
                  match 'classifications(/:classification_id)', on: :member, action: 'classifications', as: 'classifications', via: [:get, :post]
                end
                match 'classification_trees', to: 'classification_trees#index', as: 'classification_trees', via: [:get, :post]
                match 'classification_trees/:id', to: 'classification_trees#show', as: 'classification_tree', via: [:get, :post]

                match 'collections', to: 'watch_lists#index', as: 'collections', via: [:get, :post]
                match 'collections/:id', to: 'watch_lists#show', as: 'collection', via: [:get, :post]

                match 'users', to: 'users#index', as: 'users', via: [:get, :post]

                scope 'external_sources/:external_source_id' do
                  resources :things, only: [:create, :update, :destroy], controller: :external_systems, path: '', param: :external_key
                end
              end
            end
          end
          if DataCycleCore.main_config.dig(:api, :v4, :enabled)
            namespace :v4 do
              scope path: '(/:api_subversion)' do
                match 'things/deleted', to: 'contents#deleted', as: 'contents_deleted', via: [:get, :post]
                match 'things/select(/:uuids)', to: 'contents#select', as: 'contents_select', via: [:get, :post]

                match 'things', to: 'things#index', via: [:get, :post] if Rails.env.test? || Rails.env.development?
                match 'things/:id', to: 'things#show', as: 'thing', via: [:get, :post]
                match 'things/:id/:timeseries(/:format)', to: 'things#timeseries', as: 'thing_timeseries', via: [:get, :post]

                match 'universal(/:id)', to: 'universal#show', as: 'universal', via: [:get, :post]

                match 'concept_schemes', to: 'classification_trees#index', via: [:get, :post]
                match 'concept_schemes/:id', to: 'classification_trees#show', as: 'concept_scheme', via: [:get, :post]

                resources :concept_schemes, only: [], controller: :classification_trees do
                  match 'concepts(/:classification_id)', on: :member, action: 'classifications', as: 'classifications', via: [:get, :post]
                end

                match 'endpoints/:id/things(/:content_id)', to: 'contents#index', as: 'stored_filter_things', via: [:get, :post]
                match 'endpoints/:id/suggest', to: 'contents#typeahead', as: 'typeahead', via: [:get, :post]
                match 'endpoints/:id/download', to: 'downloads#endpoint', as: 'download_endpoint', via: [:get, :post]
                match 'endpoints/:id/facets/:classification_tree_label_id(/:classification_id)', to: 'classification_trees#facets', as: 'facets', via: [:get, :post]
                get 'endpoints/:id/statistics/:attribute(/:format)', to: 'contents#statistics', as: 'statistics'
                match 'endpoints/:id(/:content_id)', to: 'contents#index', as: 'stored_filter', via: [:get, :post]
                match 'endpoints/:id/:content_id/elevation_profile(/:format)', to: 'contents#elevation_profile', as: 'content_elevation_profile', via: [:get, :post]
                match 'endpoints/:id/:content_id/download', to: 'downloads#thing', as: 'download_thing', via: [:get, :post]
                match 'endpoints/:id/:content_id/:timeseries(/:format)', to: 'contents#timeseries', as: 'content_timeseries', via: [:get, :post]

                post 'collections/create', to: 'watch_lists#create'
                resources :collections, only: [], controller: :watch_lists do
                  post '/add_item(/:thing_id)', action: :add_item, on: :member, as: :add_item
                  post '/remove_item(/:thing_id)', action: :remove_item, on: :member, as: :remove_item
                  get :download_and_reset, on: :member
                end
                match 'collections', to: 'watch_lists#index', via: [:get, :post]
                match 'collections/:id', to: 'watch_lists#show', as: 'collection', via: [:get, :post]

                namespace :authentication, path: :auth do
                  post :login, defaults: { warden_strategy: 'email_password' }
                  post :renew_login
                  post :logout
                end

                namespace :users do
                  post :create
                  match '/update', action: :update, via: [:patch, :put]
                  match '/', action: :index, via: [:get, :post]
                  post :password
                  match '/password', action: :change_password, via: [:patch, :put]
                  post :resend_confirmation
                  match '/confirm', action: :confirm, via: [:patch, :put]
                  match '/:id', action: :show, as: :user, via: [:get, :post]
                end

                scope 'external_sources/:external_source_id', constraints: { external_source_id: %r{[^/]+} } do
                  match '/:external_key/timeseries(/:attribute)', via: [:put, :patch], to: 'external_systems#timeseries'
                  match '/:external_key/:attribute(/:format)', via: [:put, :patch], to: 'external_systems#timeseries', as: 'external_source_timeseries'
                  match '/concepts(/:external_key)', via: [:get, :post], to: 'classification_trees#by_external_key', as: 'classification_trees_by_external_key'
                  match '/things/select(/:external_keys)', to: 'contents#select_by_external_keys', as: 'things_select_by_external_key', via: [:get, :post]
                  match '/:external_key', via: [:get, :post], to: 'external_systems#show', as: 'external_sources'
                  match '', via: :post, to: 'external_systems#create'
                  match '(/:external_key)', via: [:put, :patch], to: 'external_systems#update', as: 'external_sources_update'
                  match '(/:external_key)', via: [:delete], to: 'external_systems#destroy', as: 'external_sources_delete'
                  match '/search/availability', via: [:get, :post], to: 'external_systems#search_availability', as: 'external_source_search_availability'
                  match '/search/additional_service', via: [:get, :post], to: 'external_systems#search_additional_service', as: 'external_source_search_additional_service'
                end

                match 'external_systems/:external_system_id/things/:id', to: 'external_systems_export#show', via: :get
              end
            end
          end
          namespace :config do
            resources :schema, only: [] do
              match '/:template_name', action: :show, on: :collection, as: :show, via: [:get, :post]
              match '/', action: :index, on: :collection, via: [:get, :post]
            end
            resources :feature, only: [] do
              match '/', action: :index, on: :collection, via: [:get, :post]
            end
          end
        end
      end

      if DataCycleCore.main_config.dig(:sync_api, :enabled)
        defaults format: :json do
          namespace :sync_api do
            if DataCycleCore.main_config.dig(:sync_api, :v1, :enabled)
              namespace :v1 do
                match 'things/deleted', to: 'contents#deleted', as: 'contents_deleted', via: [:get, :post]
                match 'things/select(/:uuids)', to: 'contents#select', as: 'contents_select', via: [:get, :post]

                match 'things', to: 'contents#index', as: 'contents_index', via: [:get, :post]
                match 'things/:id', to: 'contents#show', as: 'content_show', via: [:get, :post]

                match 'endpoints/:id/things(/:content_id)', to: 'contents#index', as: 'stored_filter_things', via: [:get, :post]
                match 'endpoints/:id(/:content_id)', to: 'contents#index', as: 'stored_filter', via: [:get, :post]

                match 'collections', to: 'watch_lists#index', via: [:get, :post]
                match 'collections/:id', to: 'watch_lists#show', as: 'collection', via: [:get, :post]

                match 'concept_schemes', to: 'concept_schemes#index', as: :concept_scheme_index, via: [:get, :post]
                match 'concept_schemes/:id', to: 'concept_schemes#show', as: :concept_scheme_show, via: [:get, :post]
                match 'concept_schemes/:id/concepts', to: 'concept_schemes#concepts', as: :concept_scheme_concept, via: [:get, :post]
              end
            end
          end
        end
      end

      defaults format: :pbf do
        namespace :mvt do
          namespace :v1 do
            scope path: '(/:api_subversion)' do
              match 'endpoints/:id/:z/:x/:y', to: 'contents#index', via: [:get, :post]
              match 'endpoints/:id', to: 'contents#index', defaults: { bbox: true }, via: [:get, :post]
              match 'things/select/:z/:x/:y(/:uuids)', to: 'contents#select', as: 'contents_select', via: [:get, :post]
              match 'things/select(/:uuids)', to: 'contents#select', defaults: { bbox: true }, as: 'contents_select_bbox', via: [:get, :post]
              match 'things/:id/:z/:x/:y', to: 'contents#show', via: [:get, :post]
              match 'concepts/select/:uuids/:z/:x/:y', to: 'classification_trees#select', as: 'concepts_select', via: [:get, :post]
            end
          end
        end
      end

      defaults format: :xml do
        namespace :xml do
          namespace :v1 do
            scope path: '(/:api_subversion)' do
              type_regexp = Regexp.new(*CONTENT_TABLES_FALLBACK.map(&:to_sym).join('|'))
              get 'endpoints/:id(/:type)(/:content_id)', to: 'contents#index', constraints: { type: type_regexp }, as: 'stored_filter'

              resources(*(CONTENT_TABLES_FALLBACK + CONTENT_TABLE).map(&:to_sym), only: [:index, :show])

              get 'contents/search(/:type)', to: 'contents#index', constraints: { type: type_regexp }, as: 'contents_search'

              # probably kill later
              resources :classification_trees, only: [:index, :show] do
                get 'classifications(/:classification_id)', on: :member, action: 'classifications', as: 'classifications'
              end

              resources :collections, only: [:index, :show], controller: :watch_lists
            end
          end
        end
      end

      if DataCycleCore.main_config.dig(:webdav, :enabled)
        defaults format: :xml do
          namespace :webdav do
            if DataCycleCore.main_config.dig(:webdav, :v1, :enabled)
              namespace :v1 do
                scope path: '(/:api_subversion)' do
                  match 'endpoints/:id/things/:file_name(.:extention)', to: 'contents#show', via: :propfind, as: 'contents_show'
                  get 'endpoints/:id/things/:file_name(.:extention)', to: 'contents#download'
                  match 'endpoints/:id/(things)', to: 'contents#index', via: :propfind, as: 'contents_index'
                  get 'endpoints/:id/(things)', to: 'contents#show_collection'
                  match 'endpoints/*whatever', to: 'contents#options', via: :options
                end
              end
            end
          end
        end
      end
    end

    namespace :object_browser do
      post :show
      post :details
      post :find
      post :render_in_overlay
    end

    resources :publications, only: :index do
      post '/', on: :collection, action: :index
    end
  end

  if DataCycleCore.main_config.dig(:api, :enabled) && DataCycleCore.main_config.dig(:webdav, :enabled)
    match '/', to: 'webdav/v1/contents#options', via: [:options] # Microsoft Explorer is weired
  end

  authenticate do
    post :add_filter, controller: :application
    post :add_tag_group, controller: :application
    post :remote_render, controller: :application
    get :holidays, controller: :application
  end

  get :reload_required, controller: :application
end
