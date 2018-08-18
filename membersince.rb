require 'rubygems'
require 'sinatra'
require 'haml'
require 'rest-client'
require 'json'
require 'time'
require 'base64'

enable :sessions

get '/' do
  if session[:access_token] && session[:access_token].length > 0
    # Retrieve full social profile
    # https://developer.yahoo.com/social/rest_api_guide/profiles_table.html
    social_profile_json = RestClient.get 'https://query.yahooapis.com/v1/yql?q=select%20*%20from%20social.profile%20where%20guid%20%3D%20me&format=json', {:Authorization => 'Bearer ' + session[:access_token]}
  
    # Fields of interest
    social_profile = JSON.parse social_profile_json
    nickname = social_profile.dig('query', 'results', 'profile', 'nickname')
    member_since = social_profile.dig('query', 'results', 'profile', 'memberSince')

    halt 500 unless nickname && member_since
  
    begin
      the_date = DateTime.parse member_since
    rescue ArgumentError
      halt
    end  
    
    session.delete :access_token
  
    haml :result, :locals => {
      :image_url => social_profile.dig('query', 'results', 'profile', 'image', 'imageUrl'),
      :nickname => nickname,
      :since_date => since_date(the_date),
      :wikipedia_link => wikipedia_link(the_date),
      :escaped_link => URI.escape(ENV['SITE'] + '/c/' + rot13(Base64.strict_encode64(nickname)) + '/' + rot13(Base64.strict_encode64(member_since)))
    }
  else
    haml "%a{:href => url('/when')} When did I create my Yahoo account? &rarr;"
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

# cached
get '/c/:nickname/:member_since' do
  nickname = Base64.decode64(rot13(params[:nickname]))
  member_since = Base64.decode64(rot13(params[:member_since]))
  
  halt 500 unless nickname && member_since
  
  begin
    the_date = DateTime.parse member_since
  rescue ArgumentError
    halt
  end 
  
  haml :cached, :locals => {
    :nickname => nickname,
    :since_date => since_date(the_date),
    :wikipedia_link => wikipedia_link(the_date)
  }
end

# FB
get '/tos' do
  haml :tos, :layout => false
end

# Duh
error 403, 404, 500 do
  haml :error
end

# utils
def rot13(str)
  str.tr("A-Za-z", "N-ZA-Mn-za-m")
end

def since_date(parsed_date)
  dow = parsed_date.strftime('%A')
  d = parsed_date.strftime('%d')
  m = parsed_date.strftime('%B')
  y = parsed_date.strftime('%G')
  
  "#{dow}, #{m} #{d}, #{y}"
end

def wikipedia_link(parsed_date)
  d = parsed_date.strftime('%d')
  m = parsed_date.strftime('%B')
  y = parsed_date.strftime('%G')
  
  "https://en.wikipedia.org/wiki/Portal:Current_events/#{m}_#{y}\##{y}_#{m}_#{d}"
end