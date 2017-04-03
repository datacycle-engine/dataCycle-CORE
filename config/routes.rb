DataCycleCore::Engine.routes.draw do

  devise_for :users, class_name: 'DataCycleCore::User', module: :devise

  root to: 'front_end#index'

  #root to: 'dash_board#home'

  resources :creative_works, only: [:index, :show]

  get  '/admin', to: 'dash_board#home'
  get  '/admin/download', to: 'dash_board#download'
  get  '/admin/import', to: 'dash_board#import'

  mount RailsDb::Engine => '/db', :as => 'db'
end
