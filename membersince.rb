require 'rubygems'
require 'sinatra'
require 'haml'
require 'rest-client'
require 'json'
require 'time'

enable :sessions

get '/' do
  if session[:access_token] && session[:access_token].length > 0
    # Retrieve full social profile
    # https://developer.yahoo.com/social/rest_api_guide/profiles_table.html
    social_profile_json = RestClient.get 'https://query.yahooapis.com/v1/yql?q=select%20*%20from%20social.profile%20where%20guid%20%3D%20me&format=json', {:Authorization => 'Bearer ' + session[:access_token]}
  
    # Fields of interest
    social_profile = JSON.parse social_profile_json
    @nickname = social_profile.dig('query', 'results', 'profile', 'nickname')
    member_since = social_profile.dig('query', 'results', 'profile', 'memberSince')

    halt 500 unless @nickname && member_since
  
    @image_url = social_profile.dig('query', 'results', 'profile', 'image', 'imageUrl')
  
    # Wikipedia Current Events Portal URL building for dummies
    begin
      the_date = DateTime.parse member_since
    rescue ArgumentError
      halt
    else
      dow = the_date.strftime('%A')
      d = the_date.strftime('%d')
      m = the_date.strftime('%B')
      y = the_date.strftime('%G')
    
      @since_date = "#{dow}, #{m} #{d}, #{y}"
      @wikipedia_url = "https://en.wikipedia.org/wiki/Portal:Current_events/#{m}_#{y}\##{y}_#{m}_#{d}"
    end  
    
    session.delete :access_token
  
    haml :yahoo
  else
    haml "%a{:href => url('/when')} When did I create my Yahoo account?"
  end
end

# OAuth authorization 
get '/when' do
  redirect 'https://api.login.yahoo.com/oauth2/request_auth?client_id=' + ENV['YDN_CLIENT_ID'] + '&response_type=token&redirect_uri=' + ENV['SITE'] + '/js-callback'  
end

# Yahoo! didn't use server flow to return access token, hence this horrible hack
get '/js-callback' do
  if params[:error]
    haml "%p I need access to your Profile information, you know.\n%p\n\t%a{:href => '/when'} &larr; Please try again"
  else
    haml :callback, :layout => false
  end
end

# I hate long URLs
post '/callback' do
  halt 500 unless params[:token]
  
  session[:access_token] = params[:token]
  
  redirect to('/')
end

# Duh
error 403, 404, 500 do
  haml :error
end