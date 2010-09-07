require 'rubygems'

require 'haml'
require 'sinatra'
require 'sqlite3'
require 'pp'

APP_DIR = File.expand_path(File.dirname(__FILE__))

restart_txt = "#{APP_DIR}/tmp/restart.txt"
File.unlink restart_txt if File.exists? restart_txt

set :views, "#{APP_DIR}/views"

helpers do
  def job_link(build_num)
    "http://build.i.page2page.net:8080/job/BooxImage/#{build_num}"
  end
end

get '/' do
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
  haml :artifacts
end
