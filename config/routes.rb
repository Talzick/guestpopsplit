# frozen_string_literal: true

GuestCta::Engine.routes.draw do
  post "/events" => "events#create"

  scope "/admin" do
    get "/dashboard" => "admin/dashboard#show"
    get "/overview" => "admin/overview#show"
    put "/baseline" => "admin/baseline#update"

    resources :tests, only: %i[create update destroy], controller: "admin/tests" do
      member do
        put :start
        put :finish
      end
    end

    resources :variants, only: %i[create update destroy], controller: "admin/variants"
  end
end
