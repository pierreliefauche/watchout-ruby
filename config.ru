# config.ru
# this file goes in APP_ROOT/config/config.ru

# require whatever your main app file is named
# for app.rb, require 'app'

require 'rubygems'
require 'bundler'

Bundler.require

require 'app'
run Sinatra::Application