require 'rubygems'
require 'sinatra'
require 'haml'
require 'rest-client'
require 'json'
require 'time'

enable :sessions

# OAuth authorization 
get '/' do
  redirect 'https://api.login.yahoo.com/oauth2/request_auth?client_id=' + ENV['YDN_CLIENT_ID'] + '&response_type=token&redirect_uri=' + ENV['SITE'] + '/js-callback'  
end

# Yahoo! didn't use server flow to return access token, hence this horrible hack
get '/js-callback' do
  haml :callback
end

# I hate long URLs
post '/callback' do
  halt 500 unless params[:token]
  
  session[:access_token] = params[:token]
  
  redirect to('/yahoo')
end

# Let's get things done
get '/yahoo' do 
  halt 500 unless session[:access_token] && session[:access_token].length > 0
  
  # Retrieve Y! GUID
  guid_json = RestClient.get 'https://social.yahooapis.com/v1/me/guid?format=json', {:Authorization => 'Bearer ' + session[:access_token]}
  guid = JSON.parse(guid_json)['guid']['value']
  
  # Retrieve full social profile
  social_profile_json = RestClient.get 'https://query.yahooapis.com/v1/yql?q=select%20*%20from%20social.profile%20where%20guid%20%3D%20%27' + guid + '%27&format=json', {:Authorization => 'Bearer ' + session[:access_token]}
  
  # Fields of interest
  nickname = JSON.parse(social_profile_json)['query']['results']['profile']['nickname']
  member_since = JSON.parse(social_profile_json)['query']['results']['profile']['memberSince']
  
  # Wikipedia Current Events Portal URL building for dummies
  begin
    the_date = DateTime.parse(member_since)
  rescue ArgumentError
    halt
  else
    dow = the_date.strftime('%A')
    d = the_date.strftime('%d')
    m = the_date.strftime('%B')
    y = the_date.strftime('%G')
  end  
  
  'Hey ' + Rack::Utils.escape_html(nickname) + ", you've been a Yahoo! member since #{dow}, #{m} #{d}, #{y}. <a href='https://en.wikipedia.org/wiki/Portal:Current_events/#{m}_#{y}\##{y}_#{m}_#{d}' target='_blank'>See what was happening back then &raquo;</a>"
end

# Duh
error 403, 404, 500 do
  "This program has performed an illegal operation and will be shut down. If the problem persists, contact the program vendor."
end