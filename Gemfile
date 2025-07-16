source "https://rubygems.org"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 7.2.2", ">= 7.2.2.1"
# The original asset pipeline for Rails [https://github.com/rails/sprockets-rails]
gem "sprockets-rails"
# Use postgresql as the database for Active Record
gem "pg", "~> 1.1"
# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"
# Use JavaScript with ESM import maps [https://github.com/rails/importmap-rails]
gem "importmap-rails"
# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem "turbo-rails"
# Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem "stimulus-rails"
# Build JSON APIs with ease [https://github.com/rails/jbuilder]
gem "jbuilder"
# Use Redis adapter to run Action Cable in production
# gem "redis", ">= 4.0.1"

# Use Kredis to get higher-level data types in Redis [https://github.com/rails/kredis]
# gem "kredis"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
# gem "bcrypt", "~> 3.1.7"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ mingw mswin x64_mingw jruby ]
# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
# gem "image_processing", "~> 1.2"

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri mingw mswin x64_mingw ], require: "debug/prelude"
  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false

  # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
  gem "rubocop-rails-omakase", require: false
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console"

  # Highlight the fine-grained location where an error occurred [https://github.com/ruby/error_highlight]
  gem "error_highlight", ">= 0.4.0", platforms: [ :ruby ]
end
# Add these gems to your existing Gemfile for code quality

# Code Quality and Testing gems
group :development, :test do
  # Code style and formatting
  gem 'rubocop', '~> 1.60', require: false
  gem 'rubocop-rails', '~> 2.23', require: false
  gem 'rubocop-performance', '~> 1.20', require: false
  gem 'rubocop-rspec', '~> 2.25', require: false if File.exist?('spec')
  
  # Security scanning
  gem 'brakeman', '~> 6.0', require: false
  gem 'bundle-audit', '~> 0.1', require: false
  
  # Testing framework
  gem 'rspec-rails', '~> 6.1' if File.exist?('spec')
  gem 'factory_bot_rails', '~> 6.4' if File.exist?('spec')
  
  # Test coverage
  gem 'simplecov', '~> 0.22', require: false
  
  # Database cleaner for tests
  gem 'database_cleaner-active_record', '~> 2.1'
  
  # Debugging
  gem 'byebug', platforms: [:mri, :mingw, :x64_mingw]
  gem 'pry-rails', '~> 0.3'
end

group :development do
  # N+1 query detection
  gem 'bullet', '~> 7.1'
  
  # Performance monitoring
  gem 'rack-mini-profiler', '~> 3.3'
  
  # Better error pages
  gem 'better_errors', '~> 2.10'
  gem 'binding_of_caller', '~> 1.0'
  
  # Code documentation
  gem 'yard', '~> 0.9', require: false
end