require 'sinatra'

class Server < Sinatra::Base
  set :server, :thin
  connections = []

  get '/subscribe' do
    headers 'Content-Type' => 'text/event-stream'
    stream :keep_open do |out|
      connections << out
    end
  end

  get '/' do
    Pathname.new(__FILE__).dirname.join('index.html').read
  end

  post '/message' do
    message = request.body.tap(&:rewind).read
    connections.each do |out|
      out << "data: #{message}\r\n\r\n"
    end
  end
end
