# config.ru
# this file goes in APP_ROOT/config/config.ru

# require whatever your main app file is named
# for app.rb, require 'app'

require 'rubygems'
require 'bundler'

Bundler.require

$LOAD_PATH << Dir.getwd
require 'app'
run Sinatra::Application