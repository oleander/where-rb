require "haml"
require "sinatra"
require "sinatra/content_for"
require "./available"
require "redis"
require "yaml"
require "json"

uri = URI.parse(ENV["REDISTOGO_URL"])
REDIS = Redis.new({
  host: uri.host, 
  port: uri.port, 
  password: uri.password
})

def rooms
  if Sinatra::Base.development?
    return Available.new.calculate
  end
  
  update = lambda do
    rooms = Available.new.calculate
    REDIS.set("stored-rooms", { rooms: rooms, stored: Time.now }.to_yaml)
    rooms
  end

  if raw = REDIS.get("stored-rooms")
    data = YAML::load(raw)
    if (Time.now - data[:stored]) > 10.minutes
      return update.call
    else
      return data[:rooms]
    end
  else
    return update.call
  end
end

get "/" do
  @rooms = rooms
  haml :index
end

get "/favs" do
  @rooms = rooms
  haml :favs
end

get "/now" do
  @rooms = rooms
  haml :now
end