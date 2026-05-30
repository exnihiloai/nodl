Rails.application.routes.draw do
  root "pages#home"

  get "/about", to: "pages#about"
  get "/try-now", to: "pages#try_now"
  get "/healthz", to: "pages#healthz"
  get "/readyz", to: "pages#readyz"

  get "/register", to: "registrations#new"
  post "/register", to: "registrations#create"
  get "/login", to: "sessions#new"
  post "/login", to: "sessions#create"
  delete "/logout", to: "sessions#destroy"
  post "/logout", to: "sessions#destroy"

  get "/dashboard", to: "dashboard#show"

  resources :workspaces, only: [] do
    post :switch, on: :member
  end

  get "/payments", to: "payments#show"
  post "/payments/checkout", to: "payments#checkout"
  get "/payments/success", to: "payments#success"
  get "/payments/cancel", to: "payments#cancel"
  post "/payments/webhook", to: "payments#webhook"

  namespace :admin do
    resources :users, only: %i[index show new create] do
      member do
        patch :update_email
        patch :update_role
        patch :update_password
        patch :update_usage
        post :generate_password
        post :deactivate
        post :reactivate
      end
    end
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
