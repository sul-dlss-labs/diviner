# frozen_string_literal: true

Rails.application.routes.draw do
  get 'up' => 'rails/health#show', as: :rails_health_check

  resources :report_runs, only: %i[index new create show update] do
    post :run, on: :member
    post :regenerate_sql, on: :member
    get :download, on: :member, defaults: { format: :csv }
    get :cocina, on: :member
  end

  root 'report_runs#new'
end
