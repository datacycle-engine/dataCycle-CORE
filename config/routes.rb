# frozen_string_literal: true

DataCycleCore::Engine.routes.draw do
  devise_for :users, class_name: 'DataCycleCore::User', module: :devise

  authenticated :user do
    root 'backend#index', as: :authenticated_root
  end

  root to: redirect('/users/sign_in')

  get '/docs/*path/:file', to: 'documentation#image', constraints: ->(request) { request.path.match?(/\.(gif|jpg|png|svg)$/) }
  get '/docs/*path', to: 'documentation#show'

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
    resources(*DataCycleCore.content_tables.map(&:to_sym), only: [:index, :show, :create, :edit, :update, :destroy]) do
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
    resources :assets, only: [:index, :show, :new, :create, :update, :destroy] do
      post 'new_asset_object', on: :collection
      delete 'remove_asset_object', on: :member
    end
  end

  resources :data_links do
    post :send_mail, on: :member
    get :download, on: :member
    get :find, on: :collection
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
  get  '/admin/import_persons', to: 'dash_board#import_persons'
  get  '/admin/import_organizations', to: 'dash_board#import_organizations'
  get  '/admin/classifications', to: 'dash_board#classifications'
  # mount RailsDb::Engine => '/db', :as => 'db'

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

        type_regexp = Regexp.new(*DataCycleCore.content_tables.map(&:to_sym).join('|'))
        resources :contents, path: ':type', constraints: { type: type_regexp }, only: [:show] do
          get :search, on: :collection
          patch :update, on: :member
        end

        get 'contents/search', to: 'contents#search'
        get 'contents/deleted', to: 'contents#deleted'

        resources :external_sources, only: [] do
          post ':external_source_id/:type/:external_key', to: 'external_sources#create', on: :collection
          patch ':external_source_id/:type/:external_key', to: 'external_sources#update', on: :collection
          delete ':external_source_id/:type/:external_key', to: 'external_sources#destroy', on: :collection
        end
      end
      namespace :v2 do
        resources :stored_filters, only: [:show], path: :endpoints do
          resources(*DataCycleCore.content_tables.map(&:to_sym), only: [:index]) do
          end
        end

        resources(*DataCycleCore.content_tables.map(&:to_sym), only: [:index, :show]) do
        end

        resources :classification_trees, only: [:index, :show] do
          get :classifications, on: :member
        end

        resources :collections, only: [:index, :show], controller: :watch_lists

        resources :external_sources, only: [] do
          post ':external_source_id/:type/:external_key', to: 'external_sources#create', on: :collection
          patch ':external_source_id/:type/:external_key', to: 'external_sources#update', on: :collection
          delete ':external_source_id/:type/:external_key', to: 'external_sources#destroy', on: :collection
        end

        get 'contents/search', to: 'contents#search'
        get 'contents/deleted', to: 'contents#deleted'
      end
    end
  end

  namespace :object_browser do
    post :show
    post :details
    post :find
  end

  post 'contents/upload', to: 'contents#upload'

  resources :publications, only: :index

  get :add_filter, controller: :application
  get :add_tag_group, controller: :application
end
