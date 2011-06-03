# coding: utf-8
$LOAD_PATH << File.join(Dir.getwd, 'lib')
require 'sinatra'
require 'less'
require 'uri'
require 'dalli'
require 'erubis'
Tilt.register :erb, Tilt[:erubis]
require 'ProgrammeTV'
require 'curb'

helpers do	
	def my_forward(method, path)
		call env.merge("PATH_INFO" => path, "REQUEST_METHOD" => method.upcase)
	end
	
	def label_from_wday(wday)
		week_days = ['dimanche','lundi','mardi','mercredi','jeudi','vendredi','samedi']
		week_days[wday]
	end
	
	def random_string
		return (100+rand(899)).to_s
	end
end

configure do
	set :environment, :development
	# Memcache client
	set :cache, Dalli::Client.new(ENV['MEMCACHE_SERVERS'], :username => ENV['MEMCACHE_USERNAME'], :password => ENV['MEMCACHE_PASSWORD'], :expires_in => 300)
end

before do
  @programme_tv = ProgrammeTV.new
	@wtoday = Time.new.wday
end

get '/' do
	erb :index
end

get '/night/:wday' do |wday|
	erb :night, :locals => {:wday => wday}
end

get '/show' do
	erb :show, :locals => {:show => @programme_tv.show(params[:link]), :time => params[:time]}
end
