DataCycleCore::Engine.routes.draw do

  devise_for :users, class_name: 'DataCycleCore::User', module: :devise

  root to: 'backend#index'

  get  '/info',    to: 'frontend#info'
  get  '/settings',    to: 'backend#settings'

  resources :creative_works, only: [:index, :show, :create, :edit, :update]
  resources :persons, only: [:index, :show, :create, :edit, :update]
  resources :places, only: [:index, :show, :create, :edit, :update]
  resources :data_links do
    post :send_mail, on: :member
  end
  resources :watch_lists do
    get :removeItem, on: :member
    get :addItem, on: :member
  end

  get  '/admin', to: 'dash_board#home'
  get  '/admin/download', to: 'dash_board#download'
  get  '/admin/import', to: 'dash_board#import'
  get  '/admin/import_templates', to: 'dash_board#import_templates'
  get  '/admin/import_classifications', to: 'dash_board#import_classifications'
  get  '/admin/import_persons', to: 'dash_board#import_persons'
  get  '/admin/classifications', to: 'dash_board#classifications'
  #mount RailsDb::Engine => '/db', :as => 'db'

  #backend validation endpoints
  match '/validatecreativework(/:id)', to: 'creative_works#validate_single_data', via: [:patch, :post]
  match '/validateperson(/:id)', to: 'persons#validate_single_data', via: [:patch, :post]
  match '/validateplace(/:id)', to: 'places#validate_single_data', via: [:patch, :post]


  defaults format: :json do
    namespace :api do
      namespace :v1 do
        resources :classification, only: [:index]

        resources :collections, only: [:index, :show], controller: :watch_lists

        type_regexp = Regexp.new([:creative_works, :persons, :places].join("|"))
        resources :contents, path: ':type', constraints: { type: type_regexp }, only: [:show]
      end
    end
  end

  get '/objectbrowser', to: 'object_browser#show'
  get '/objectbrowser/find', to: 'object_browser#find'

end
