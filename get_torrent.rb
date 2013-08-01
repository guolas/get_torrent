require 'nokogiri'
require 'open-uri'
require 'rest-client'
require 'json'

csrf = ''
if ARGV.size == 0
  puts "Error, a parameter is required"
  exit(-1)
end
base_uri = ARGV[0]

results_page = Nokogiri::HTML(open(base_uri))

pirate_bay_row = results_page.css('dl dt a[href^="http://thepiratebay"]')

pirate_bay_http_link = pirate_bay_row.attr('href').content

pirate_bay_https_link = pirate_bay_http_link.sub('http://', 'https://')

tpb_result = Nokogiri::HTML(open(pirate_bay_https_link))

magnet_link = tpb_result.css('div.download a').first.attr('href')

puts "Recovered the magnet link:"
puts magnet_link
puts "----------"

# add the magnet link using Transmission RPC protocol
server_uri = 'localhost'
server_port = '9091'
resource_uri = '/transmission/rpc'

request_uri = server_uri + ":" + server_port + resource_uri
request_parameters = {}
request_headers = {}
request_headers["X-Transmission-Session-Id"] = csrf

RestClient.post( request_uri, request_parameters.to_json, request_headers) do |response, request, result|
  if response.code == 409
    puts "Wrong or non-existent CSRF"
    csrf = response.headers[:x_transmission_session_id] 
    print "Got CSRF: "
  else
    print "Correct CSRF: "
  end
  print csrf + "\n"
  puts "----------"
end

request_headers["X-Transmission-Session-Id"] = csrf
request_parameters["method"] = "torrent-add"
request_parameters["arguments"] = {"filename" => magnet_link}

puts "Trying to add the Torrent file using the following request:"
puts request_parameters
puts "----------"

RestClient.post(request_uri, request_parameters.to_json, request_headers) do |response, request, result|
  puts response.code
  if response.code == 200
    response = JSON.parse(response)
    if response["arguments"].has_key?"torrent-duplicate"
      print "Torrent duplicated, removing newest duplicate ..."
      request_parameters["method"] = "torrent-remove"
      request_parameters["arguments"] = {"ids" => response["arguments"]["torrent-duplicate"]["id"]}
      RestClient.post(request_uri, request_parameters.to_json, request_headers) do |response|
        print "[DONE]\n"
      end
    else
      puts "Magnet link added correctly"
    end
  end
  puts response
end
