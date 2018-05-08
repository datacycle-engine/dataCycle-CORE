DataCycleCore::Engine.routes.draw do
  devise_for :users, class_name: 'DataCycleCore::User', module: :devise

  authenticated :user do
    root 'backend#index', as: :authenticated_root
  end

  root to: redirect('/users/sign_in')

  get  '/info', to: 'frontend#info'
  get  '/settings', to: 'backend#settings'
  resources :users, only: [:index, :edit, :update, :destroy] do
    post :unlock, on: :member
    post :create_user, on: :collection
    get :search, on: :collection
  end
  resources :user_organizations do
    post :create_user, on: :collection
  end
  resources :user_groups

  scope '(/watch_lists/:watch_list_id)', defaults: { watch_list_id: nil } do
    resources(*DataCycleCore.content_tables.map(&:to_sym), only: [:index, :show, :create, :edit, :update, :history, :history_detail, :destroy]) do
      # resources :creative_works, only: [:index, :show, :create, :edit, :update, :history, :history_detail, :destroy] do
      post :import, on: :collection
      get 'history', on: :member
      get 'history_detail', on: :member
      get 'compare', on: :member
    end
  end

  resources(*DataCycleCore.content_tables.map(&:to_sym)) do
    post :validate, on: :member
    post :validate, on: :collection
    patch :set_life_cycle, on: :member
  end

  resources :subscriptions, only: [:index, :create, :destroy]
  # resources :events, only: [:index, :show, :create, :edit, :update, :destroy]
  resources :stored_filters, only: [:index, :create, :update, :destroy], path: :search_history do
    get :search, on: :collection
  end
  resources :classification_tree_labels, only: :show

  scope('files') do
    resources :assets, only: [:index, :show, :new, :create, :destroy] do
      post 'new_asset_object', on: :collection
      delete 'remove_asset_object', on: :member
    end
  end

  resources :data_links do
    post :send_mail, on: :member
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

  # backend validation endpoints
  match '/validatecreativework(/:id)', to: 'creative_works#validate_single_data', via: [:patch, :post]
  match '/validateperson(/:id)', to: 'persons#validate_single_data', via: [:patch, :post]
  match '/validateorganization(/:id)', to: 'organizations#validate_single_data', via: [:patch, :post]
  match '/validateplace(/:id)', to: 'places#validate_single_data', via: [:patch, :post]

  defaults format: :json do
    namespace :api do
      namespace :v1 do
        resources :stored_filters, only: [:show], path: :endpoints

        resources :classification_trees, only: [:index, :show] do
          get :classifications, on: :member
        end

        resources :collections, only: [:index, :show], controller: :watch_lists

        type_regexp = Regexp.new(*DataCycleCore.content_tables.map(&:to_sym).join('|'))
        resources :contents, path: ':type', constraints: { type: type_regexp }, only: [:show] do
          get :search, on: :collection
          patch :update, on: :member
        end

        get 'contents/search', to: 'contents#search'
        get 'contents/get_deleted', to: 'contents#get_deleted'

        resources :external_sources, only: [] do
          post ':external_source_id/:type/:external_key', to: 'external_sources#create', on: :collection
          patch ':external_source_id/:type/:external_key', to: 'external_sources#update', on: :collection
          delete ':external_source_id/:type/:external_key', to: 'external_sources#destroy', on: :collection
        end
      end
    end
  end

  namespace :object_browser do
    post :show
    post :details
    post :find
  end

  post 'contents/new_embedded_object', to: 'contents#new_embedded_object'
  post 'contents/render_embedded_object', to: 'contents#render_embedded_object'
  get 'contents/gpx', to: 'contents#gpx'

  resources :publications, only: :index

  get :add_filter, controller: :application
  get :add_tag_group, controller: :application
end
