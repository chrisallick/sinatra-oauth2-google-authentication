require 'sinatra'
require 'oauth2'
require 'json'

enable :sessions

# Scopes are space separated strings
SCOPES = ['https://www.googleapis.com/auth/userinfo.email'].join(' ')

unless G_API_CLIENT = ENV['G_API_CLIENT']
    raise "You must specify the G_API_CLIENT env variable"
end

unless G_API_SECRET = ENV['G_API_SECRET']
    raise "You must specify the G_API_SECRET env veriable"
end

def client
    client ||= OAuth2::Client.new(G_API_CLIENT, G_API_SECRET, {
            :site => 'https://accounts.google.com', 
            :authorize_url => "/o/oauth2/auth", 
            :token_url => "/o/oauth2/token"
        })
end

get '/' do
    erb :index
end

# this is a URL to test
# if authentication is working
get '/protected/test/' do
    at = OAuth2::AccessToken.new(client,session[:access_token])
    if session[:access_token]
        if session[:access_token] == at.token
            email = at.get('https://www.googleapis.com/userinfo/email?alt=json').parsed
            puts email
        end
    else
        redirect "/"
    end
end

get "/auth" do
    redirect client.auth_code.authorize_url(:redirect_uri => redirect_uri, :scope => SCOPES, :access_type => "offline", :hd => "anomaly.com")
end

# http://stackoverflow.com/questions/26812104/how-does-a-website-revoke-disconnect-oauth-access
# https://developers.google.com/identity/protocols/OAuth2WebServer?hl=en
get "/revoke/" do  
    uri = URI('https://accounts.google.com/o/oauth2/revoke')
    params = { :token => session[:access_token] }
    uri.query = URI.encode_www_form(params)
    response = Net::HTTP.get(uri)

    session[:access_token] = nil

    redirect "/"
end

get '/oauth2callback' do
    access_token = client.auth_code.get_token(params[:code], :redirect_uri => redirect_uri)
    session[:access_token] = access_token.token
    @message = "Successfully authenticated with the server"
    @access_token = session[:access_token]

    redirect "/"
end

def redirect_uri
    uri = URI.parse(request.url)
    uri.path = '/oauth2callback'
    uri.query = nil
    uri.to_s
end