set :application, "build_dashboard"
set :repository,  "git@github.com:onyx-intl/build_dashboard.git"

default_run_options[:pty] = true
set :user, "hudson"
set :scm, :git
set :branch, "master"
set :deploy_via, :remote_cache
set :deploy_to, "/var/www/dashboard"
set :use_sudo, false

role :web, "build.i.page2page.net"
role :app, "build.i.page2page.net"
role :db,  "build.i.page2page.net", :primary => true

namespace :deploy do
  task :start do ; end
  task :stop do ; end
  task :restart, :roles => :app, :except => { :no_release => true } do
    run "#{try_sudo} touch #{File.join(current_path,'tmp','restart.txt')}"
    run "#{try_sudo} chmod a+rw #{File.join(current_path,'tmp','restart.txt')}"
  end
end
