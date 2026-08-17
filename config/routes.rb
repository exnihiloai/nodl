Rails.application.routes.draw do
  root "pages#home"

  get "/about", to: "pages#about"

  # Vertical marketing pages exist once per language: the URL fixes the locale
  # (see ApplicationController#current_locale) so crawlers index a stable
  # language per URL. DE and EN variants reference each other via hreflang
  # (SeoHelper#seo_link_tags).
  get "/fuer/aerzte", to: "pages#for_doctors", as: :for_doctors, defaults: { locale: "de" }
  get "/fuer/zahnaerzte", to: "pages#for_dentists", as: :for_dentists, defaults: { locale: "de" }
  get "/fuer/gedankenkarussell", to: "pages#for_overthinkers", as: :for_overthinkers, defaults: { locale: "de" }
  get "/fuer/tagebuch", to: "pages#for_journaling", as: :for_journaling, defaults: { locale: "de" }
  get "/fuer/interviews", to: "pages#for_interviews", as: :for_interviews, defaults: { locale: "de" }
  get "/fuer/coaches", to: "pages#for_coaches", as: :for_coaches, defaults: { locale: "de" }
  get "/for/doctors", to: "pages#for_doctors", as: :for_doctors_en, defaults: { locale: "en" }
  get "/for/dentists", to: "pages#for_dentists", as: :for_dentists_en, defaults: { locale: "en" }
  get "/for/racing-mind", to: "pages#for_overthinkers", as: :for_overthinkers_en, defaults: { locale: "en" }
  get "/for/journaling", to: "pages#for_journaling", as: :for_journaling_en, defaults: { locale: "en" }
  get "/for/interviews", to: "pages#for_interviews", as: :for_interviews_en, defaults: { locale: "en" }
  get "/for/coaches", to: "pages#for_coaches", as: :for_coaches_en, defaults: { locale: "en" }

  # Operator content pages (articles/guides) rendered from private/views/content/<locale>/<slug>.
  get "/artikel", to: "content_pages#index", as: :artikel_index,
      format: false, defaults: { locale: "de" }
  get "/articles", to: "content_pages#index", as: :article_index,
      format: false, defaults: { locale: "en" }
  get "/artikel/:slug", to: "content_pages#show", as: :artikel,
      format: false, defaults: { locale: "de" }, constraints: { slug: /[a-z0-9-]+/ }
  get "/articles/:slug", to: "content_pages#show", as: :article,
      format: false, defaults: { locale: "en" }, constraints: { slug: /[a-z0-9-]+/ }
  get "/licenses", to: "licenses#show", as: :licenses
  get "/help/integrity-proof", to: "pages#integrity_proof", as: :integrity_proof_help
  get "/changelog", to: "changelogs#show", as: :changelog, format: false
  get "/changelog/:version_slug", to: "changelogs#show", as: :changelog_entry,
      format: false, constraints: { version_slug: /v[\d.]+/ }
  get "/sitemap.xml", to: "sitemap#show", defaults: { format: :xml }, as: :sitemap
  get "/robots.txt", to: "robots#show", as: :robots
  get "/llms.txt", to: "llms#show", as: :llms
  get "/llms-full.txt", to: "llms#full", as: :llms_full
  get "/impressum", to: "legal_pages#imprint", as: :imprint
  get "/datenschutz", to: "legal_pages#privacy", as: :privacy
  get "/agb", to: "legal_pages#terms", as: :terms
  get "/ki-transparenz", to: "legal_pages#ai_transparency", as: :ai_transparency
  get "/subprozessoren", to: "legal_pages#subprocessors", as: :subprocessors
  get "/sicherheit", to: "legal_pages#security", as: :security
  get "/avv", to: "legal_pages#dpa", as: :dpa
  get "/try-now", to: "pages#try_now"
  get "/healthz", to: "pages#healthz"
  get "/readyz", to: "pages#readyz"

  match "/404", to: "errors#not_found", via: :all

  get "/register", to: "registrations#new"
  post "/register", to: "registrations#create"
  get "/login", to: "sessions#new"
  post "/login", to: "sessions#create"
  delete "/logout", to: "sessions#destroy"
  post "/logout", to: "sessions#destroy"
  post "/users/auth/google_oauth2", to: "users/omniauth_callbacks#passthru", as: :user_google_oauth2_omniauth_authorize
  match "/users/auth/google_oauth2/callback", to: "users/omniauth_callbacks#google_oauth2", via: %i[get post]
  match "/users/auth/failure", to: "users/omniauth_callbacks#failure", via: %i[get post]

  patch "/locale/:locale", to: "locales#update", as: :locale

  get "/dashboard", to: "dashboard#show"
  resources :recording_sessions, only: %i[create show destroy] do
    post :finalize, on: :member
    get :download_original_audio, on: :member
    get :download_integrity_archive, on: :member
  end
  resources :documents, only: %i[show update] do
    get :download, on: :member
  end
  resources :transformer_profiles, only: %i[show new create edit update destroy] do
    delete "example_files/:attachment_id", to: "transformer_profiles#remove_example_file", on: :member, as: :example_file
  end

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
        patch :update_integrity_sealing
        patch :update_entitlement
        post :generate_password
        post :deactivate
        post :reactivate
      end
    end
  end

  get "up" => "rails/health#show", as: :rails_health_check

  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  resource :settings, only: %i[show update]
  resources :push_subscriptions, only: %i[create destroy]

  # Streams decrypted Active Storage blobs (audio playback/download) for the
  # EncryptedDisk service. `rails_blob_path` redirects here; the token in the URL
  # is signed/encrypted and never exposes the per-blob key. See config/storage.yml.
  mount ActiveStorageEncryption::Engine => "/active-storage-encryption"
end
