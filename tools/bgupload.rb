require 'rubygems'

require 'cloudfiles'
require 'sqlite3'

class Uploader
  def self.connect(&block)
    uploader = Uploader.new
    block.call(uploader)
  end

  def initialize
    read_credentials
    @cf = CloudFiles::Connection.new(:username => @user,
                                     :api_key => @apikey)
  end

  # Upload a file, return a public URL.
  def upload_to_bucket(bucket, name, file_path)
    container = @cf.container(bucket)
    prefix = (0...24).map{65.+(rand(25)).chr}.join
    object = container.create_object "#{prefix}/#{name}"
    object.load_from_filename file_path
    return object.public_url
  end

  private

  def user=(a_user)
    @user = a_user
  end

  def apikey=(a_key)
    @apikey = a_key
  end

  def read_credentials
    credentials = IO.read(File.join(ENV['HOME'], '.cloudfiles'))
    instance_eval credentials
  end
end

db = SQLite3::Database.new("#{ENV['HOME']}/builds.db")
rows = db.execute("select artifact, path from upload_jobs " +
                  "where status='pending'");
jobs = []
rows.each {|row| jobs << {:artifact => row[0], :path => row[1]}}
Uploader.connect do |uploader|
  jobs.each do |job|
    db.execute("update upload_jobs set status='uploading' " +
               "where artifact='#{job[:artifact]}'")
    begin
      url = uploader.upload_to_bucket("Software Releases", job[:artifact],
                                      job[:path])
      db.execute("update upload_jobs set status='uploaded', url='#{url}'" +
                 " where artifact='#{job[:artifact]}'")
    rescue
      db.execute("update upload_jobs set status='pending', url='#{url}'" +
                 " where artifact='#{job[:artifact]}' and status='uploading'")
    end
  end
end
