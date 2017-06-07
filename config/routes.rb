DataCycleCore::Engine.routes.draw do

  devise_for :users, class_name: 'DataCycleCore::User', module: :devise

  root to: 'backend#index'

  get  '/vuejs',    to: 'backend#vue'
  get  '/info',    to: 'frontend#info'
  get  '/settings',    to: 'backend#settings'

  resources :creative_works, only: [:index, :show, :new, :create, :edit, :update]

  get  '/admin', to: 'dash_board#home'
  get  '/admin/download', to: 'dash_board#download'
  get  '/admin/import', to: 'dash_board#import'
  get  'admin/import_templates', to: 'dash_board#import_templates'
  get  'admin/import_classifications', to: 'dash_board#import_classifications'
  #mount RailsDb::Engine => '/db', :as => 'db'

  match '/validatetest(/:id)', to: 'creative_works#validate_single_data', via: [:patch, :post]

  namespace :api do
    namespace :v1 do
      resources :classification, only: [:index]
    end
  end
  
  #dev routes for michi
  get '/demoarticle', to: 'creative_works#demoarticle'
  get '/demotopic', to: 'creative_works#demotopic'

end
