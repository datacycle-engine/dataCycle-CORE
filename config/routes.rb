# frozen_string_literal: true

DataCycleCore::Engine.routes.draw do
  devise_for :users, class_name: 'DataCycleCore::User', module: :devise,
                     controllers: { passwords: 'data_cycle_core/passwords' }

  authenticated :user do
    root 'backend#index', as: :authenticated_root
  end

  CONTENT_TABLES_FALLBACK ||= ['organizations', 'persons', 'events', 'places', 'creative_works'].freeze
  CONTENT_TABLE ||= ['things'].freeze

  root to: redirect('/users/sign_in')

  get '/docs/*path/:file', to: 'documentation#image', constraints: ->(request) { request.path.match?(/\.(gif|jpg|png|svg)$/) }
  get '/docs/*path', to: 'documentation#show'

  get '/schema', to: 'schema#index'

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
    resources(*(CONTENT_TABLES_FALLBACK + CONTENT_TABLE).map(&:to_sym), only: [:index, :show, :create, :edit, :update, :destroy], controller: :things) do
      post :import, on: :collection
      get 'history/:history_id', action: :history, on: :member, as: :history
      get 'compare', on: :member
      get 'external/:external_key/edit', action: 'edit_by_external_key', on: :collection
      get :load_more_linked_objects, on: :member
      get :gpx, on: :member
      post :validate, on: :member
      post :validate, on: :collection
      get :new_embedded_object, on: :member
      get :render_embedded_object, on: :member
    end
  end

  resources :subscriptions, only: [:index, :create, :destroy]
  resources :stored_filters, only: [:index, :create, :update, :destroy], path: :search_history do
    get :search, on: :collection
  end
  resources :classification_tree_labels, only: :show

  scope('files') do
    resources :assets, only: [:index, :show, :create, :update, :destroy] do
      get :find, on: :collection
    end
  end

  resources :data_links do
    post :send_mail, on: :member
    get :download, on: :member
    get :get_text_file, on: :member
  end

  resources :watch_lists do
    delete :remove_item, on: :member
    get :add_item, on: :member
  end

  resources :classifications, only: [:index, :create] do
    put :update, on: :collection
    patch :update, on: :collection
    delete :destroy, on: :collection
    get :search, on: :collection
    get :download, on: :collection
  end

  get  '/admin', to: 'dash_board#home'
  get  '/admin/download', to: 'dash_board#download'
  get  '/admin/import', to: 'dash_board#import'
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
        type_regexp = Regexp.new(*CONTENT_TABLES_FALLBACK.map(&:to_sym).join('|'))
        get 'endpoints/:id(/:type)', to: 'contents#index', constraints: { type: type_regexp }, as: 'stored_filter'

        resources(*(CONTENT_TABLES_FALLBACK + CONTENT_TABLE).map(&:to_sym), only: [:index, :show])

        get 'contents/search(/:type)', to: 'contents#index', constraints: { type: type_regexp }, as: 'contents_search'
        get 'contents/deleted(/:type)', to: 'contents#deleted', constraints: { type: type_regexp }, as: 'contents_deleted'

        resources :classification_trees, only: [:index, :show] do
          get :classifications, on: :member
        end

        resources :collections, only: [:index, :show], controller: :watch_lists

        scope 'external_sources/:external_source_id' do
          resource :things, only: [:create, :update, :destroy], controller: :external_sources, path: ':type/:external_key', constraints: { type: /creative_work/ }
        end

        scope 'external_systems/:external_system_id' do
          resource :external_systems, only: [:show], controller: :external_systems, path: ':ids'
        end
      end
      namespace :v3 do
        type_regexp = Regexp.new(*CONTENT_TABLES_FALLBACK.map(&:to_sym).join('|'))
        get 'endpoints/:id(/:type)', to: 'contents#index', constraints: { type: type_regexp }, as: 'stored_filter'

        resources(*(CONTENT_TABLES_FALLBACK + CONTENT_TABLE).map(&:to_sym), only: [:index, :show])

        get 'contents/search(/:type)', to: 'contents#index', constraints: { type: type_regexp }, as: 'contents_search'
        get 'contents/deleted(/:type)', to: 'contents#deleted', constraints: { type: type_regexp }, as: 'contents_deleted'

        resources :classification_trees, only: [:index, :show] do
          get :classifications, on: :member
        end

        resources :collections, only: [:index, :show], controller: :watch_lists

        scope 'external_sources/:external_source_id' do
          resource :things, only: [:create, :update, :destroy], controller: :external_sources, path: ':type/:external_key', constraints: { type: /creative_work/ }
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
  post 'contents/new', to: 'contents#new'

  resources :publications, only: :index

  get :add_filter, controller: :application
  get :add_tag_group, controller: :application
  post :remote_render, controller: :application
end
