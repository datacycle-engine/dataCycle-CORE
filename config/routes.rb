# frozen_string_literal: true

DataCycleCore::Engine.routes.draw do
  devise_for :users, class_name: 'DataCycleCore::User', module: :devise,
                     controllers: { passwords: 'data_cycle_core/passwords', sessions: 'data_cycle_core/sessions' }.merge(Devise.try(:omniauth_configs).present? ? { omniauth_callbacks: 'data_cycle_core/omniauth_callbacks' } : {})

  authenticated :user do
    root 'backend#index', as: :authenticated_root
  end

  CONTENT_TABLES_FALLBACK ||= ['organizations', 'persons', 'events', 'places', 'products', 'media_objects', 'creative_works'].freeze
  CONTENT_TABLE ||= ['things'].freeze

  root to: redirect('/users/sign_in')

  get '/docs/*path/:file', to: 'documentation#image', constraints: ->(request) { request.path.match?(/\.(gif|jpg|png|svg)$/) }
  get '/docs/*path', to: 'documentation#show'
  get '/docs', to: 'documentation#show'

  get '/assets/:klass/:id/:version(/:file)', to: 'missing_asset#show', constraints: {
    klass: /(image|audio|video|pdf|text_file|data_cycle_file)/,
    id: /[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}/,
    file: /.*/
  }

  get '/schema', to: 'schema#index'
  get '/schema/:id', to: 'schema#show', as: :schema_details

  get  '/info', to: 'frontend#info'
  get  '/settings', to: 'backend#settings'
  resources :users, only: [:index, :edit, :update, :destroy] do
    post :unlock, on: :member
    post :create_user, on: :collection
    get :search, on: :collection
    get :become
  end
  resources :user_organizations do
    post :create_user, on: :collection
  end
  resources :user_groups

  scope '(/watch_lists/:watch_list_id)', defaults: { watch_list_id: nil } do
    resources(*(CONTENT_TABLES_FALLBACK + CONTENT_TABLE).map(&:to_sym), controller: :things) do
      post :import, on: :collection
      get 'history/:history_id', action: :history, on: :member, as: :history
      get 'compare/(:source_id)', on: :member, action: :compare, as: 'compare'
      get 'external/:external_key/edit', action: 'edit_by_external_key', on: :collection
      get :load_more_linked_objects, on: :member
      get :load_more_related, on: :member
      get :download_zip, on: :member
      get 'download/(:serialize_format)', on: :member, action: :download, as: 'download'
      get :download_indesign, on: :member
      get :create_duplication, on: :member
      post :validate, on: :member
      post :validate, on: :collection
      get :new_embedded_object, on: :member
      get :render_embedded_object, on: :member
      get 'split_view/:source_id', on: :member, action: :split_view, as: 'split_view'
    end
  end

  resources :subscriptions, only: [:index, :create, :destroy]
  resources :stored_filters, only: [:index, :create, :update, :destroy], path: :search_history do
    get :search, on: :collection
    get :download_zip, on: :member
    get 'download/(:serialize_format)', on: :member, action: :download, as: 'download'
    post :add_to_watchlist, on: :collection
  end
  resources :classification_tree_labels, only: :show, param: :ctl_id

  defaults format: :json do
    resource :content_locks, only: :update do
      post :destroy, on: :collection
    end
  end

  scope('files') do
    resources :assets, only: [:index, :show, :create, :update, :destroy] do
      get :find, on: :collection
      post :duplicate, on: :member
    end
  end

  resource :downloads, only: [] do
    get '/things(/:id)(/:serialize_format)(/:version)', on: :member, action: 'things'
    get '/thing_collections(/:id)', on: :member, action: 'thing_collections'
    get '/watch_lists(/:id)(/:serialize_format)', on: :member, action: 'watch_lists'
    get '/watch_list_collections(/:id)', on: :member, action: 'watch_list_collections'
    get '/stored_filters(/:id)(/:serialize_format)', on: :member, action: 'stored_filters'
    get '/stored_filter_collections(/:id)', on: :member, action: 'stored_filter_collections'
  end

  resources :data_links do
    post :send_mail, on: :member
    get :download, on: :member
    get :get_text_file, on: :member
  end

  resources :watch_lists do
    delete :remove_item, on: :member
    get :add_item, on: :member
    get :bulk_edit, on: :member
    patch :bulk_update, on: :member
    post :validate, on: :member
    get :download_zip, on: :member
    get :download_indesign, on: :member
    get 'download/(:serialize_format)', on: :member, action: :download, as: 'download'
    delete :bulk_delete, on: :member
  end

  resources :classifications, only: [:index, :create] do
    put :update, on: :collection
    patch :update, on: :collection
    delete :destroy, on: :collection
    get :search, on: :collection
    get :find, on: :collection
    get :download, on: :collection
  end

  scope :admin do
    resources :external_sources, only: [] do
      get :authorize, on: :member
      get :callback, on: :member
    end
  end

  get  '/admin', to: 'dash_board#home'
  get  '/admin/download/:id', to: 'dash_board#download', as: 'admin_download'
  get  '/admin/download_import/:id', to: 'dash_board#download_import', as: 'admin_download_import'
  get  '/admin/import/:id', to: 'dash_board#import', as: 'admin_import'
  get  '/admin/import_full/:id', to: 'dash_board#import_full', as: 'admin_import_full'
  get  '/admin/import_templates', to: 'dash_board#import_templates'
  get  '/admin/import_classifications', to: 'dash_board#import_classifications'
  get  '/admin/import_config', to: 'dash_board#import_config'
  get  '/admin/import_external_systems', to: 'dash_board#import_external_systems'
  get  '/admin/classifications', to: 'dash_board#classifications'

  defaults format: :json do
    namespace :api do
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
          resource :things, only: [:show, :create, :update, :destroy], controller: :external_sources, path: ':type/:external_key', constraints: { type: /creative_work/ }
        end
      end
      namespace :v2 do
        scope path: '(/:api_subversion)' do
          type_regexp = Regexp.new(*CONTENT_TABLES_FALLBACK.map(&:to_sym).join('|'))
          get 'endpoints/:id(/:type)', to: 'contents#index', constraints: { type: type_regexp }, as: 'stored_filter'

          resources(*(CONTENT_TABLES_FALLBACK + CONTENT_TABLE).map(&:to_sym), only: [:index, :show]) do
            get :gpx, on: :member
          end

          get 'contents/search(/:type)', to: 'contents#index', constraints: { type: type_regexp }, as: 'contents_search'
          get 'contents/deleted(/:type)', to: 'contents#deleted', constraints: { type: type_regexp }, as: 'contents_deleted'

          resources :classification_trees, only: [:index, :show] do
            get :classifications, on: :member
          end

          resources :collections, only: [:index, :show], controller: :watch_lists

          scope 'external_sources/:external_source_id' do
            resource :things, only: [:create, :update, :destroy], controller: :external_sources, path: ':type/:external_key', constraints: { type: /creative_work/ }
          end

          resources :external_systems, only: [:show], controller: :external_systems
        end
      end
      namespace :v3 do
        scope path: '(/:api_subversion)' do
          type_regexp = Regexp.new(*CONTENT_TABLES_FALLBACK.map(&:to_sym).join('|'))
          match 'endpoints/:id(/:type)(/:content_id)', to: 'contents#index', constraints: { type: type_regexp }, as: 'stored_filter', via: [:get, :post]

          resources(*(CONTENT_TABLES_FALLBACK + CONTENT_TABLE).map(&:to_sym), only: []) do
            get :gpx, on: :member
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
            resources :things, only: [:create, :update, :destroy], controller: :external_sources, path: '', param: :external_key
          end
        end
      end

      namespace :v4 do
        scope path: '(/:api_subversion)' do
          match 'things/deleted', to: 'contents#deleted', as: 'contents_deleted', via: [:get, :post]

          match 'things', to: 'things#index', via: [:get, :post] if Rails.env.test? || Rails.env.development?
          match 'things/:id', to: 'things#show', as: 'thing', via: [:get, :post]

          match 'universal(/:id)', to: 'universal#show', as: 'universal', via: [:get, :post]

          match 'concept_schemes', to: 'classification_trees#index', via: [:get, :post]
          match 'concept_schemes/:id', to: 'classification_trees#show', as: 'concept_scheme', via: [:get, :post]

          resources :concept_schemes, only: [], controller: :classification_trees do
            match 'concepts(/:classification_id)', on: :member, action: 'classifications', as: 'classifications', via: [:get, :post]
          end

          match 'endpoints/:id(/:content_id)', to: 'contents#index', as: 'stored_filter', via: [:get, :post]

          post 'collections/create', to: 'watch_lists#create'
          resources :collections, only: [], controller: :watch_lists do
            post :add_item, on: :member
            post :remove_item, on: :member
            get :download_and_reset, on: :member
          end
          match 'collections', to: 'watch_lists#index', via: [:get, :post]
          match 'collections/:id', to: 'watch_lists#show', as: 'collection', via: [:get, :post]

          namespace :authentication, path: :auth do
            post :login
            post :renew_login
            post :logout
          end

          post 'users/create', to: 'users#create'
          match 'users', to: 'users#index', via: [:get, :post]
          match 'users/:id', to: 'users#show', as: 'user', via: [:get, :post]
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

  namespace :object_browser do
    post :show
    post :details
    post :find
  end

  post 'contents/upload', to: 'contents#upload'
  # post 'contents/new', to: 'contents#new'

  resources :publications, only: :index

  get :add_filter, controller: :application
  get :add_tag_group, controller: :application
  post :remote_render, controller: :application
  get :reload_required, controller: :application
end
