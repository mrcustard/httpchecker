require 'json'
require 'sinatra'
require 'time'
require 'typhoeus'
require 'thread'
require "net/http"
require "uri"

queue = Queue.new

port        = ENV['PORT'] || 6079
healthcheck = ENV['HEALTHCHECK'] || '/healthcheck'
serviceName = ENV['SERVICE_NAME'] || ''
frequency   = ENV['FREQUENCY'] || 60
frequency   = frequency.to_f
urls_text   = ENV['URL_LIST'] || ''
url_locs    = urls_text.split(' ')
problem_owner = '' # specify a problem owner
customer = '' # specify a customer
webhook_service = '' # server that will process alerts when the value of the page is 400 or above.
results     = ''

set :bind, '0.0.0.0'
set :port, port

set :public_folder, 'public'
  
get '/' do
  erb :index, :locals => {:serviceName => serviceName}
end
  
get '/results' do 
  content_type :json  
  unless queue.empty?()
    results = queue.pop()
  end
  results
end

get '/healthcheck' do
  'OK'
end

checker = Thread.new do
  loop do
    requests = {}
    oksites = []
    problemsites = []
    urls = []
    hydra = Typhoeus::Hydra.new;
    url_locs.each do |loc|
      urls.concat(Net::HTTP.get_response(URI.parse(loc)).body.split("\n"))
    end
    urls.each do |url|
      requests[url] = Typhoeus::Request.new(url)
      hydra.queue(requests[url])
    end 
    hydra.run
    t = Time.new
    requests.each do |url, req|
      res = req.response
      if res.code < 400
        oksites << { "response" => res.code, "total_time" => res.total_time, "url" => url }
      else
        problemsites << { "response" => res.code, "total_time" => res.total_time, "url" => url }
      end
    end
    if problemsites != nil 
      problemsites.each do |site|
        sitename = site['url'].gsub(/http:\/\//, '')
        data = { 'Clientname' => customer ,'Url' => sitename, 'message' => "Please notify #{problem_owner} - Problem with #{site['url']}" }
        jsondata = JSON.generate(data)
        uri = URI.parse("http://#{webhook_service}/webhook/httpchecker")
        req = Net::HTTP::Post.new(uri.path, initheader = {'Content-type' => 'application/json'} )
        req.basic_auth uri.user, uri.password
        req.body = jsondata
        response = Net::HTTP.new(uri.host, uri.port).start { |http| http.request(req) }
      end
    end
    hydra = nil  
    queue.clear()
    queue.push(JSON.generate(oksites + problemsites))
    sleep frequency
  end
end
