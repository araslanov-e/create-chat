# encoding: utf-8

require 'rubygems'
require 'bundler/setup'
require 'eventmachine'
require 'em-websocket'
require 'logger'
require 'yaml'
require 'erb'


WD = File.dirname(__FILE__)
CFG = YAML.load(File.read(File.join(WD, 'config.yml')))

VER = CFG[:ver]
HOST = CFG[:host]
ADDR = CFG[:addr]
WS_PORT = CFG[:ws_port]
HTTP_PORT = CFG[:http_port]
MSGS = CFG[:msgs]

WEB = ERB.new(File.read(File.join(WD, 'client.erb'))).result


class ClientsManager
  
  def initialize
    @cli = []
  end
  
  def add(c)
    @cli << c
    say MSGS[:in] % c.nick
    c.say MSGS[:hi]
  end
  
  def del(c)
    @cli.delete c
    say MSGS[:out] % c.nick
  end
  
  def say(msg)
    @cli.each do |c|
      c.say msg
    end
  end
  
  def nicks
    @cli.map do |c|
      c.nick
    end
  end
  
end


class Client < Struct.new(:nick, :ws)

  CMDS = [:ls, :help, :chn, :srv]
  
  def listen(msg)
    msg.match /^(\$?)(.*)$/ do |m|
      if m[1] == '$'
        if z = m[2].match(/^(.*?)\s(.*)$/)
          a = z[1].to_sym
          send a, z[2] if CMDS.include? a
        else
          a = m[2].to_sym
          send a if CMDS.include? a
        end
      else
        $clients.say MSGS[:say] % [nick, msg]
      end
    end
  end
  
  def say(msg)
    ws.send msg.chomp
  end
  
  def err(msg)
    say MSGS[:err] % msg
  end
  
  def ls(*opts)
    say MSGS[:ls] % $clients.nicks.join(', ')
  end
  
  def chn(*opts)
    if opts.any?
      old = nick
      self.nick = opts.first.to_s
      $clients.say MSGS[:chn] % [old, nick]
    end
  end
  
  def srv(*opts)
    name = `uname -a`.chomp
    mem = `free -m`.split
    say MSGS[:srv] % [name, mem[7], mem[15], mem[16]]
  end
  
  def help(*opts)
    say MSGS[:help]
  end
  
end


module HttpServer

  def receive_data data
    $logger.info "Получен HTTP-запрос: #{ data }"
    send_data <<RESP
HTTP/1.0 200 OK
Content-Type: text/html; charset=UTF-8
Content-Length: #{ WEB.bytesize }

#{ WEB }
RESP
    close_connection_after_writing
  end
  
end


EventMachine.run do

  $logger = Logger.new(File.join(WD, 'server.log'))
  $logger.level = Logger::DEBUG
  
  $clients = ClientsManager.new

  EventMachine::WebSocket.start host: ADDR, port: WS_PORT do |ws|
    
    c = Client.new("Без имени ##{ rand(100..999) }", ws)
  
    ws.onopen do
      $clients.add c
      $logger.info "Установлено соединение c #{ c.nick }"
    end

    ws.onclose do
      $clients.del c
      $logger.info "Соединение c #{ c.nick } закрыто"
    end
    
    ws.onmessage do |msg|
      c.listen msg
      $logger.info "Сообщение от #{ c.nick }: #{ msg }"
    end
    
    ws.onerror do |err|
      c.err err.message
      $logger.info "Ошибка у #{ c.nick }: #{ err.message }"
    end
    
  end
  
  EventMachine.start_server ADDR, HTTP_PORT, HttpServer
  
  $logger.info "Create Chat (версия #{ VER })"
  $logger.info "WebSocket сервер запущен на #{ ADDR }:#{ WS_PORT }"
  $logger.info "HTTP сервер запущен на #{ ADDR }:#{ HTTP_PORT }"
  
end

