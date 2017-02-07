# require 'byebug'
require 'netrc'
require 'highline'
require 'typhoeus'
require 'json'
require 'uri'

module Klimt
  class GravityClient
    attr_reader :token

    HOSTS = { production: 'api.artsy.net', staging: 'stagingapi.artsy.net' }
    DEFAULT_PAGE_SIZE = 20

    def initialize(env:)
      @host = set_host(env)
      @token = find_or_create_token
    end

    def find(type:, id:)
      uri = "https://#{@host}/api/v1/#{type}/#{id}"
      response = Typhoeus.get(uri, headers: headers)
      response.body
    end

    def list(type, params)
      params = Hash[ params.map{|pair| pair.split('=')} ]
      uri = "https://#{@host}/api/v1/#{type}"
      response = Typhoeus.get(uri, headers: headers, params: params)
      response.body
    end

    def count(type, params)
      params = Hash[ params.map{|pair| pair.split('=')} ]
      params[:size] = 0
      params[:total_count] = true
      uri = "https://#{@host}/api/v1/#{type}"
      response = Typhoeus.get(uri, headers: headers, params: params)
      response.headers['X-Total-Count']
    end

    def search(term, params, indexes=nil)
      params = Hash[ params.map{|pair| pair.split('=')} ]
      params[:term] = term
      params[:indexes] = indexes unless indexes.nil?
      uri = "https://#{@host}/api/v1/match"
      response = Typhoeus.get(uri, headers: headers, params: params, params_encoding: :rack) # encode arrays correctly
      response.body
    end

    # partners

    def partner_locations(partner_id, params)
      params = Hash[ params.map{|pair| pair.split('=')} ]
      uri = "https://#{@host}/api/v1/partner/#{partner_id}/locations"
      response = Typhoeus.get(uri, headers: headers, params: params)
      response.body
    end

    private

    def headers
      {
        'X-ACCESS-TOKEN' => @token,
        'User-Agent' => "Klimt #{Klimt::VERSION}"
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
