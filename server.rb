# ab -n 10000 -c 100 -p ./section_one/ostechnix.txt localhost:1234/
# head -c 100000 /dev/urandom > section_one/ostechnix_big.txt

require 'socket'
require './lib/response'
require './lib/request'
MAX_EOL = 2

socket = TCPServer.new(ENV['HOST'], ENV['PORT'])

def handle_request(request_text, client)
  request  = Request.new(request_text)
  puts "#{client.peeraddr[3]} #{request.path}"

  response = route_request(request)

  response.send(client)

  client.shutdown
end

def route_request(request)
  comand, query_params = request.path.split('?')
  puts query_params.inspect, comand.inspect
  path = query_params.split('=')[1]
  data = case comand 
  when '/ls'
    dir_response(path)
  when '/cat'
    file_response(path)
  end
end

def file_response(file_path)
  if File.exist?(file_path)
    data = File.read(file_path)
    Response.new(code: 200, data: data)
  else 
    Response.new(code: 404, data: "File not found")
  end
end

def dir_response(dir_path)
  if File.exist?(dir_path)
    data = `ls -la #{dir_path}`
    Response.new(code: 200, data: data)
  else 
    Response.new(code: 404, data: "Directory doesn't exist")
  end
end

def handle_connection(client)
  puts "Getting new client #{client}"
  request_text = ''
  eol_count = 0

  loop do
    buf = client.recv(1)
    puts "#{client} #{buf}"
    request_text += buf

    eol_count += 1 if buf == "\n"

    if eol_count == MAX_EOL
      handle_request(request_text, client)
      break
    end

    #sleep 1
  end
rescue => e
  puts "Error: #{e}"

  response = Response.new(code: 500, data: "Internal Server Error")
  response.send(client)

  client.close
end

puts "Listening on #{ENV['HOST']}:#{ENV['PORT']}. Press CTRL+C to cancel."

loop do
  Thread.start(socket.accept) do |client|
    handle_connection(client)
  end
end

