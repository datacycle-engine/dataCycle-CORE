DataCycleCore::Engine.routes.draw do

  devise_for :users, class_name: 'DataCycleCore::User', module: :devise

  root to: 'dash_board#home'

  resources :creative_works, only: [:index, :show]

  get  '/download', to: 'dash_board#download'
  get  '/import', to: 'dash_board#import'

  #mount RailsDb::Engine => '/db', :as => 'db'
end
