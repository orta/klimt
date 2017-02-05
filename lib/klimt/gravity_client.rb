# require 'byebug'
require 'netrc'
require 'highline'
require 'typhoeus'
require 'json'
require 'uri'

module Klimt
  class GravityClient
    HOSTS = { production: 'api.artsy.net', staging: 'stagingapi.artsy.net' }
    DEFAULT_PAGE_SIZE = 20

    def initialize(env:)
      @host = set_host(env)
      @token = find_or_create_token
    end

    def find(type, id)
      response = Typhoeus.get("https://#{@host}/api/v1/#{type}/#{id}", headers: headers)
      response.body
    end

    def list(type, params)
      params = Hash[ params.map{|pair| pair.split('=')} ]
      response = Typhoeus.get("https://#{@host}/api/v1/#{type}?#{URI.encode_www_form(params)}", headers: headers)
      response.body
    end

    def count(type, params)
      params = Hash[ params.map{|pair| pair.split('=')} ]
      params[:size] = 0
      params[:total_count] = true
      response = Typhoeus.get("https://#{@host}/api/v1/#{type}?#{URI.encode_www_form(params)}", headers: headers)
      response.headers['X-Total-Count']
    end

    def search(term, params, options)
      params = Hash[ params.map{|pair| pair.split('=')} ]
      params[:term] = term
      search_uri = "https://#{@host}/api/v1/match?#{URI.encode_www_form(params)}"
      if options[:indexes]
      # this is weird cuz same key can exist multiple times
        search_uri << "&" << options[:indexes].map{|index| "indexes[]=#{index}"}.join('&')
      end
      response = Typhoeus.get(search_uri, headers: headers)
      response.body
    end

    private

    def headers
      {
        'X-ACCESS-TOKEN': @token
      }
    end

    def set_host(env)
      HOSTS[env.to_sym]
    end

    def find_or_create_token
      _user, token = Netrc.read[@host]
      token ||= generate_token
    end

    def generate_token
      email, pass = get_credentials
      params = {
        client_id: ENV['KLIMT_ID'],
        client_secret: ENV['KLIMT_SECRET'],
        grant_type: 'credentials',
        email: email,
        password: pass        
      }
      response = Typhoeus.get "https://#{@host}/oauth2/access_token", params: params
      body = JSON.parse(response.body )
      if response.success?
        body['access_token'].tap do |new_token|
          netrc = Netrc.read
          netrc[@host] = email, new_token
          netrc.save
        end
      else
        puts "Login failed: #{body['error_description']}"
        exit 1
      end
    end

    def get_credentials
      cli = HighLine.new
      cli.say "No login credentials found in .netrc"
      cli.say "Please login now"
      cli.say "-----"
      email = cli.ask("Artsy email    : ") { }
      pass  = cli.ask("Artsy password : ") { |q| q.echo = "x" }
      [email, pass]
    end
  end
end
