gem 'mongoid', '~> 4.0.0'
gem 'sass', '~> 3.3.9'

remove_file 'Gemfile'
create_file 'Gemfile' do <<-TEXT
source 'https://rubygems.org'

gem 'spring', group: 'development'
TEXT
end

remove_file 'app/controllers/application_controller.rb'
create_file 'app/controllers/application_controller.rb' do <<-TEXT
class ApplicationController < ActionController::Base
  include RocketCMS::Controller
end
TEXT
end

create_file 'config/navigation.rb' do <<-TEXT
# empty file to please simple_navigation, we are not using it
# See https://github.com/rs-pro/rocket_cms/blob/master/app/controllers/concerns/rs_menu.rb
TEXT
end

#gsub_file 'Gemfile', /^(.*)sass-rails(.*)$/, ''
gem 'rocket_cms'

gem 'sass-rails', github: 'rails/sass-rails', ref: '3a9e47db7d769221157c82229fc1bade55b580f0'
gem 'compass-rails', '~> 2.0.0'
gem 'compass', '~> 1.0.0.alpha.20'

gem 'slim-rails'
gem 'rs_russian'
gem 'sentry-raven'

gem 'cancancan'

gem_group :development do
  gem 'better_errors'
  gem 'binding_of_caller'
  gem 'pry-rails'

  gem 'capistrano', '~> 3.2.0', require: false
  gem 'rvm1-capistrano3', require: false
  gem 'glebtv-capistrano-unicorn', require: false
  gem 'capistrano-bundler', require: false
  gem 'capistrano-rails', require: false
  gem 'capistrano-rails-console'

  gem 'hipchat'

  gem 'coffee-rails-source-maps'
  gem 'compass-rails-source-maps'
end

gem_group :test do
  #gem 'capybara'
  #gem 'poltergeist'
  #gem 'simplecov', require: false
  gem 'rspec-rails'
  gem 'database_cleaner'
  gem 'email_spec'
  gem 'glebtv-mongoid-rspec'
  #gem 'rspec-collection_matchers'
  #gem 'timecop'
  gem 'ffaker'
  gem 'factory_girl_rails'
end

remove_file 'config/routes.rb'
create_file 'config/routes.rb' do <<-TEXT
Rails.application.routes.draw do
end
TEXT
end
route "mount Ckeditor::Engine => '/ckeditor'"

application "config.i18n.enforce_available_locales = true"
application "config.i18n.available_locales = [:ru, :en]"
application "config.i18n.default_locale = :ru"
application "config.i18n.locale = :ru"

create_file 'README.md', "## Project generated by RocketCMS\n\n"

create_file '.ruby-version', "#{RUBY_VERSION}\n"
create_file '.ruby-gemset', "#{app_name}\n"

run 'bundle install --without production'
# generate "mongoid:config"

create_file 'config/mongoid.yml' do <<-TEXT
development:
  sessions:
    default:
      database: #{app_name.downcase}_development
      hosts:
          - localhost:27017
test:
  sessions:
    default:
      database: #{app_name.downcase}_test
      hosts:
          - localhost:27017
TEXT
end

generate "rocket_cms:admin"
generate "rocket_cms:ability"
generate "rocket_cms:layout"
generate "devise:install"
generate "devise", "User"
generate "rspec:install"

route "resources :news, only: [:index, :show]"
route "get 'search' => 'search#index', as: :search"
route "get 'contacts' => 'contacts#new', as: :contacts"
route "post 'contacts' => 'contacts#create', as: :create_contacts"
route "get 'contacts/sent' => 'contacts#sent', as: :contacts_sent"
route "root 'home#index'"
route "resources :pages, only: [:show]"
route "get '*slug' => 'pages#show'"

gsub_file 'config/application.rb', /^(.*)config.time_zone(.*)$/, "config.time_zone = 'Europe/Moscow'"

#capify!

remove_file 'db/seeds.rb'
admin_pw = (0...8).map { (65 + rand(26)).chr }.join
create_file 'db/seeds.rb' do <<-TEXT
admin_pw = "#{admin_pw}"
User.destroy_all
User.create!(email: 'admin@#{app_name.downcase}.ru', password: admin_pw, password_confirmation: admin_pw)
TEXT
end

remove_file 'Capfile'
create_file 'Capfile' do <<-TEXT
# Load DSL and Setup Up Stages
require 'capistrano/setup'

# Includes default deployment tasks
require 'capistrano/deploy'

require 'rvm1/capistrano3'
require 'capistrano/bundler'
require 'capistrano/rails/assets'
#require "whenever/capistrano"

require 'capistrano/unicorn'

require 'capistrano/rails/console'

# Loads custom tasks from `lib/capistrano/tasks' if you have any defined.
Dir.glob('lib/capistrano/tasks/*.cap').each { |r| import r }
TEXT
end

remove_file 'public/robots.txt'
create_file 'public/robots.txt' do <<-TEXT
User-Agent: *
Disallow: /
TEXT
end

port = rand(100..999) * 10

create_file 'unicorn.conf' do <<-TEXT
listen #{port}
worker_processes 1
timeout 120
TEXT
end

create_file 'config/unicorn.rb' do <<-TEXT
rails_env = ENV['RAILS_ENV'] || 'production'

deploy_to = "/data/#{app_name.downcase}/app"
#{'rails_root = "#{deploy_to}/current"'}
#{'pid_file = "#{deploy_to}/shared/tmp/pids/unicorn.pid"'}
#{'log_file = "#{deploy_to}/shared/log/unicorn.log"'}
#{'err_log_file = "#{deploy_to}/shared/log/unicorn.error.log"'}

old_pid_file = pid_file + '.oldbin'

worker_processes 1
working_directory rails_root

timeout 120

# Specify path to socket unicorn listens to,
# we will use this in our nginx.conf later

listen "127.0.0.1:#{port}"

pid pid_file

# Set log file paths
stderr_path err_log_file
stdout_path log_file

# http://tech.tulentsev.com/2012/03/deploying-with-sinatra-capistrano-unicorn/
# NOTE: http://unicorn.bogomips.org/SIGNALS.html
preload_app true

# make sure that Bundler finds the Gemfile
before_exec do |server|
  ENV['BUNDLE_GEMFILE'] = File.join( rails_root, 'Gemfile' )
end

before_fork do |server, worker|
  # при использовании preload_app = true здесь должно быть закрытие всех открытых сокетов

  # Mongoid сам заботится о переконнекте
  # http://two.mongoid.org/docs/upgrading.html

  # http://stackoverflow.com/a/9498372/2041969
  # убиваем параллельный старый-процесс просле старта нового
  if File.exists?( old_pid_file )
    begin
      Process.kill( "QUIT", File.read( old_pid_file ).to_i )
    rescue Errno::ENOENT, Errno::ESRCH
      puts "Old master alerady dead"
    end
  end
end

after_fork do |server, worker|
  # pid-ы дочерних процессов
  #{'child_pid_file = server.config[:pid].sub(".pid", ".#{worker.nr}.pid")'}
  #{'system( "echo #{Process.pid} > #{child_pid_file}" )'}
end= ENV['RAILS_ENV'] || 'production'
TEXT
end

create_file 'config/deploy.rb' do <<-TEXT
set :user, "#{app_name.downcase}"
set :application, '#{app_name.downcase}'
set :scm, :git
set :repo_url, 'git@github.com:rs-pro/#{app_name.downcase}.git'

# ask :branch, proc { `git rev-parse --abbrev-ref HEAD`.chomp }
set :branch, ENV["REVISION"] || ENV["BRANCH_NAME"] || "master"

#{'set :deploy_to, "/data/#{fetch :application}/app"'}

# require 'hipchat/capistrano'
# set :hipchat_token, ""
# set :hipchat_room_name, "#{app_name}"
# set :hipchat_announce, false

set :rvm_type, :user
#{'set :rvm_ruby_version, "2.1.2@#{fetch :application}"'}
set :use_sudo, false

set :keep_releases, 20

set :linked_files, %w{config/mongoid.yml config/secrets.yml}
set :linked_dirs, %w{log tmp vendor/bundle public/assets public/system public/uploads public/ckeditor_assets public/sitemap}

namespace :db do
  desc "Create the indexes defined on your mongoid models"
  task :create_mongoid_indexes do
    on roles(:app) do
      execute :rake, "db:mongoid:create_indexes"
    end
  end
end

namespace :deploy do
  task :restart do
  end
  #after :finishing, 'deploy:cleanup'
  desc "Update the crontab"
  task :update_crontab do
    on roles(:app) do
      #{'execute "cd #{release_path}; #{fetch(:tmp_dir)}/#{fetch :application}/rvm-auto.sh . bundle exec whenever --update-crontab #{fetch :user} --set \'environment=#{fetch :stage}&current_path=#{release_path}\'; true"'}
    end
  end
end

after 'deploy:publishing', 'deploy:restart'
after 'deploy:restart', 'unicorn:duplicate' 
# before "deploy:update_crontab", 'rvm1:hook'
# after "deploy:restart", "deploy:update_crontab"
TEXT
end

create_file 'config/deploy/production.rb' do <<-TEXT
set :stage, :production

server 'rscz.ru', user: '#{app_name.downcase}', roles: %w{web app db}

set :rails_env, 'production'
set :unicorn_env, 'production'
set :unicorn_rack_env, 'production'
TEXT
end

create_file 'lib/tasks/dl.thor' do <<-TEXT
class Dl < Thor
  package_name "dl"
  include Thor::Actions

  no_commands do
    def load_env
      return if defined?(Rails)
      require File.expand_path("../../../config/environment", __FILE__)
    end

    def env_from
      'production'
    end
    def ssh_host
      '#{app_name.downcase}.ru'
    end
    def ssh_user
      '#{app_name.downcase}'
    end
    def ssh_opts
      {}
    end

    def remote_dump_path
      '/data/#{app_name.downcase}/tmp_dump'
    end
    def remote_app_path
      "/data/#{app_name.downcase}/app/current"
    end

    def local_auth(conf)
      if conf['password'].nil?
        ""
      else
        #{'"-u #{conf["username"]} -p #{conf["password"]}]"'}
      end
    end
  end

  desc "download", "clone files and DB from production"
  def download
    load_env
    require 'net/ssh'

    puts "backup remote DB via ssh"
    r_conf = nil
    Net::SSH.start(ssh_host, ssh_user, ssh_opts) do |ssh|
      r_conf = YAML.load(ssh.exec!("cat #{'#{remote_app_path}'}/config/mongoid.yml"))[env_from]['sessions']['default']
      puts ssh.exec!("rm -R #{'#{remote_dump_path}'}")
      puts ssh.exec!("mkdir -p #{'#{remote_dump_path}'}")
      dump = "mongodump -u #{'#{r_conf[\'username\']} -p #{r_conf[\'password\']} -d #{r_conf[\'database\']} --authenticationDatabase #{r_conf[\'database\']} -o #{remote_dump_path}"'}
      puts dump
      puts ssh.exec!(dump)
    end
    conf = YAML.load_file(Rails.root.join('config', 'mongoid.yml'))[Rails.env]['sessions']['default']
    db_to = conf['database']
    db_path = Rails.root.join("tmp", "dmp", "dump", db_to).to_s
    #{'`mkdir -p #{db_path}`'}
    #{'rsync = "rsync -e ssh --progress -lzuogthvr #{ssh_user}@#{ssh_host}:#{remote_dump_path}/#{r_conf[\'database\']}/ #{db_path}/"'}
    puts rsync
    pipe = IO.popen(rsync)
    while (line = pipe.gets)
      print line
    end

    puts "restoring DB"
    if Rails.env.staging?
      #{'restore = "mongorestore --drop -d #{db_to} -u #{remote_db_user} -p #{remote_db_pass} --authenticationDatabase admin #{db_path}"'}
    else
      #{'restore = "mongorestore --drop -d #{db_to} #{local_auth(conf)} #{db_path}"'}
    end
    puts restore
    pipe = IO.popen(restore)
    while (line = pipe.gets)
      print line
    end

    #{'rsync = "rsync -e ssh --progress -lzuogthvr #{ssh_user}@#{ssh_host}:#{remote_app_path}/public/system/ #{Rails.root.join(\'public/system\')}/"'}
    puts rsync
    pipe = IO.popen(rsync)
    while (line = pipe.gets)
      print line
    end

    #{'rsync = "rsync -e ssh --progress -lzuogthvr #{ssh_user}@#{ssh_host}:#{remote_app_path}/public/ckeditor_assets/ #{Rails.root.join(\'public/ckeditor_assets\')}/"'}
    puts rsync
    pipe = IO.popen(rsync)
    while (line = pipe.gets)
      print line
    end
    puts "cloned files"
    puts "done"
  end
end
TEXT
end
remove_file 'app/views/layouts/application.html.erb'

application do <<-TEXT
  config.generators do |g|
    g.test_framework :rspec
    g.view_specs false
    g.helper_specs false
    g.feature_specs false
    g.template_engine :slim
    g.stylesheets false
    g.javascripts false
    g.helper false
    g.fixture_replacement :factory_girl, :dir => 'spec/factories'
  end
TEXT
end

remove_file 'app/assets/stylesheets/application.css'
create_file 'app/assets/stylesheets/application.css.sass' do <<-TEXT
@import 'compass'
@import 'rocket_cms'

#wrapper
  width: 960px
  margin: 0 auto
  #sidebar
    float: left
    width: 200px
  #content
    float: right
    width: 750px

@import "compass/layout/sticky-footer"
+sticky-footer(50px)
TEXT
end

remove_file 'app/assets/javascripts/application.js'
create_file 'app/assets/javascripts/application.js.coffee' do <<-TEXT
#= require rocket_cms
TEXT
end

git :init
git add: "."
git commit: %Q{ -m 'Initial commit' }

