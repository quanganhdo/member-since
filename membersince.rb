require 'rubygems'
require 'sinatra'
require 'haml'
require 'rest-client'
require 'json'

enable :sessions

get '/' do
  redirect 'https://api.login.yahoo.com/oauth2/request_auth?client_id=' + ENV['YDN_CLIENT_ID'] + '&response_type=token&redirect_uri=' + ENV['SITE'] + '/js-callback'  
end

get '/js-callback' do
  haml :callback
end

post '/callback' do
  session[:access_token] = params[:token]
  
  redirect to('/yahoo')
end

get '/yahoo' do 
  guid_json = RestClient.get 'https://social.yahooapis.com/v1/me/guid?format=json', {:Authorization => 'Bearer ' + session[:access_token]}
  guid = JSON.parse(guid_json)['guid']['value']
  
  member_since_json = RestClient.get 'https://query.yahooapis.com/v1/yql?q=select%20memberSince%20from%20social.profile%20where%20guid%20%3D%20%27' + guid + '%27&format=json', {:Authorization => 'Bearer ' + session[:access_token]}
  
  JSON.parse(member_since_json)['query']['results']['profile']['memberSince']
end
