require 'sinatra'
require 'rest-client'
require 'json'

class Lisonja < Sinatra::Base
  enable :raise_errors
  disable :dump_errors
  disable :show_exceptions

  get "/" do
    if @@service_url
      "I am Lisonja, I think you're swell. (registered as #{@@service_url})"
    else
<<-EOT
  Register this service:
    <form action="/register" method="POST">
      <label for="service_registration_url">Service Registration API URL</label>
      <input id="service_registration_url" name="service_registration_url" type="text" />
      <input value="Register" type="submit" />
    </form>
EOT
    end
  end
  
  post "/register" do
    puts "register from #{params.inspect}"
    Lisonja.create_service(params[:service_registration_url])
    redirect "/"
  end

  get "/terms" do
    "Agree to our terms, or else..."
  end

  post "/api/1/customers/:customer_id/compliment_generators" do |customer_id|
    params = JSON.parse(request.body.read)
    next_id = @@generators_count += 1
    customer = @@customers_hash[customer_id.to_s]
    generator = ComplimentGenerator.new(
                  next_id,
                  rand.to_s[2,10],
                  "#{ENV["URL_FOR_LISONJA"]}/api/1/customers/#{customer_id}/compliment_generators/#{next_id}")
    customer.compliment_generators << generator
    #TODO: Actually create the generator
    headers 'Location' => generator.url
    generator.to_json
  end

  class ComplimentGenerator < Struct.new(:id, :api_key, :url)
    def as_json(*args)
      {
        :url => url,
        :configuration_url => nil, #meaning, no configuration possible
        :vars => {
          "COMPLIMENTS_API_KEY" => api_key,
          "CIA_BACKDOOR_PASSWORD" => "toast"
        }
      }
    end
  end

  class Customer < Struct.new(:id, :name, :api_url, :messages_url, :invoices_url, :url)
    def as_json(*args)
      {
        :url => url,
        :configuration_required => false,
        :configuration_url  => nil, #meaning, no configuration possible
        :provisioned_services_url  => "#{url}/compliment_generators"
      }
    end
    def compliment_generators
      @compliment_generators ||= []
    end
  end

  # post_params = {
  #    name:         name,
  #    url:          url,
  #    messages_url: messages_url,
  #    invoices_url: invoices_url
  #  }
  post '/api/1/customers' do
    params = JSON.parse(request.body.read)
    next_id = @@customer_count += 1
    customer = Customer.new(
                  next_id, 
                  params['name'], 
                  params['url'], 
                  params['messages_url'], 
                  params['invoices_url'], 
                  "#{ENV["URL_FOR_LISONJA"]}/api/1/customers/#{next_id}")
    @@customers_hash[next_id.to_s] = customer
    headers 'Location' => customer.url
    customer.to_json
  end

  def self.reset!
    @@service_url = nil
    @@customer_count = 0
    @@generators_count = 0
    @@customers_hash = {}
  end

  def self.create_service(service_registration_url)
    unless @@service_url
      service_creation_params = {
        :service =>
        {
          :name =>                     "Lisonja",
          :description =>              "my compliments to the devops",
          :service_accounts_url =>     "#{ENV["URL_FOR_LISONJA"]}/api/1/customers",
          :home_url =>                 "#{ENV["URL_FOR_LISONJA"]}/",
          :terms_and_conditions_url => "#{ENV["URL_FOR_LISONJA"]}/terms",
          :vars => [
              "COMPLIMENTS_API_KEY",
              "CIA_BACKDOOR_PASSWORD"
          ]
        }
      }
      response = RestClient.post(
                          service_registration_url,
                          service_creation_params.to_json,
                          :content_type => :json,
                          :accept => :json, :user_agent => "Lisonja")
      response_data = JSON.parse(response.body)
      @@service_url = response.headers[:location]
    end
    @@service_url
  end

  def self.customers
    @@customers_hash.values
  end

end