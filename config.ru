require 'pathname'
$:.unshift Pathname.new(__FILE__).dirname
require 'sprockets'
require 'coffee_script'
require 'flatware_web_formatter'

map "/assets" do
  environment = Sprockets::Environment.new
  environment.append_path 'javascripts'
  run environment
end

run Server
