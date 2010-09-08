require 'rubygems'

require 'haml'
require 'sinatra'
require 'sinatra/session'
require 'sqlite3'
require 'pp'

APP_DIR = File.expand_path(File.dirname(__FILE__))
$:.unshift("#{APP_DIR}/onyx-ruby/lib")

require 'onyx/pop_auth'
require 'onyx/config_loader'

restart_txt = "#{APP_DIR}/tmp/restart.txt"
File.unlink restart_txt if File.exists? restart_txt

config = Onyx::ConfigLoader.load_file("#{ENV['HOME']}/.onyx/dashboard")

set :views, "#{APP_DIR}/views"
set :session_fail, '/login'
set :session_secret, 'ANHxzA7rvxKH9z4A'

helpers do
  def job_link(build_num)
    "http://build.i.page2page.net:8080/job/BooxImage/#{build_num}"
  end
end

get '/login' do
  if session?
    redirect '/'
  else
    haml :login
  end
end

post '/login' do
  if params[:user] and is_valid_pop3_account(:host => config.get(:pop3_host),
                                             :user => params[:user],
                                             :password => params[:password])
    session_start!
    session[:user] = params[:user]
    redirect '/'
  else
    redirect '/login'
  end
end

get '/' do
  session!
  db = SQLite3::Database.new( "#{ENV['HOME']}/builds.db" )
  rows = db.execute("select distinct branch from builds;")
  bnames = []
  rows.each {|row| bnames << row[0]}
  @branches = {}
  bnames.each do |bname|
    branch = {}
    rows = db.execute("select distinct profile from builds " +
                      "where branch='#{bname}'")
    branch['profiles'] = []
    rows.each {|row| branch['profiles'] << row[0]}

    rows = db.execute("select distinct kernel from builds " +
                      "where branch='#{bname}'")
    branch['kernels'] = []
    rows.each {|row| branch['kernels'] << row[0]}

    branch['builds'] = {}
    branch['kernels'].each do |kernel|
      branch['builds'][kernel] = {}
      branch['profiles'].each do |profile|
        rows = db.execute("select build_num, build_id from builds " +
                          "where branch='#{bname}' and kernel='#{kernel}' " +
                          "and profile='#{profile}' order by build_num " +
                          "desc limit 1")
        build_num, build_id = rows[0]
        branch['builds'][kernel][profile] = {:id => build_id, :num => build_num}
      end
    end
    @branches[bname] = branch
  end
  haml :index
end

get "/history/:branch/:kernel/:profile" do
  @branch, @kernel, @profile = params[:branch], params[:kernel], params[:profile]
  db = SQLite3::Database.new( "#{ENV['HOME']}/builds.db" )
  rows = db.execute("select build_num, build_id from builds " +
                    "where branch='#{@branch}' and kernel='#{@kernel}' " +
                    "and profile='#{@profile}' order by build_num desc")
  @builds = []
  rows.each {|row| @builds << {:num => row[0], :id => row[1]}}
  haml :history
end

def artifacts_dir(build_id)
  "#{ENV['HOME']}/jobs/BooxImage/builds/#{build_id}/archive/artifacts"
end

get "/artifacts/:build_id" do
  @build_id = params[:build_id]
  dir = artifacts_dir(@build_id)
  @artifacts = Dir.new(dir).select {|f| File.file? "#{dir}/#{f}"}
  @status = {}
  @urls = {}
  db = SQLite3::Database.new( "#{ENV['HOME']}/builds.db" )
  @artifacts.each do |artifact|
    rows = db.execute("select status, url from upload_jobs where " +
                      "artifact='#{artifact}'")
    if rows && rows.length > 0
      @status[artifact], @urls[artifact] = rows[0]
    end
  end
  haml :artifacts
end

def artifact_path(build_id, artifact)
  "#{artifacts_dir build_id}/#{artifact}"
end

get "/upload/:build_id/:artifact" do
  build_id = params[:build_id]
  artifact = params[:artifact]
  # TODO: check if the artifact has already been uploaded.
  db = SQLite3::Database.new( "#{ENV['HOME']}/builds.db" )
  db.execute("create table if not exists upload_jobs " +
             "(artifact, path, status, url)")
  db.execute("insert into upload_jobs " +
             "(artifact, path, status) " +
             "values ( :artifact, :path, :status )",
             "artifact" => artifact,
             "path" => artifact_path(build_id, artifact),
             "status" => "pending")
  redirect "/artifacts/#{build_id}"
end
