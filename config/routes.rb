Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      namespace :user do
        post 'sign_in', to: 'sessions#sign_in'
        delete 'sign_out', to: 'sessions#sign_out'
        get 'me', to: 'sessions#me'
      end
    end
  end
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
end
