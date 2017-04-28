DataCycleCore::Engine.routes.draw do

  devise_for :users, class_name: 'DataCycleCore::User', module: :devise

  root to: 'backend#index'

  get  '/vuejs',    to: 'backend#vue'

  #root to: 'dash_board#home'

  resources :creative_works, only: [:index, :show, :new, :create]

  get  '/admin', to: 'dash_board#home'
  get  '/admin/download', to: 'dash_board#download'
  get  '/admin/import', to: 'dash_board#import'

  #mount RailsDb::Engine => '/db', :as => 'db'
end
