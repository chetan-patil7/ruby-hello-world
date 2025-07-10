Rails.application.routes.draw do
  root 'home#index'
  
  # Health check endpoint
  get '/health', to: proc { [200, {}, ['OK']] }
end
