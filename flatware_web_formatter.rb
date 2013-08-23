require 'sinatra'

class Server < Sinatra::Base
  set :server, :thin
  connections = []
  pathname = Pathname.new(__FILE__).dirname


  get '/subscribe' do
    headers 'Content-Type' => 'text/event-stream'
    stream :keep_open do |out|
      connections << out
    end
  end

  get '/' do
    pathname.join('index.html').read
  end

  get '/spec' do
    pathname.join('spec/SpecRunner.html').read
  end

  post '/message' do
    message = request.body.tap(&:rewind).read
    connections.each do |out|
      out << "data: #{message}\r\n\r\n"
    end
  end
end
