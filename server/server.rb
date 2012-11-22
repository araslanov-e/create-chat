# encoding: utf-8

require 'rubygems'
require 'eventmachine'
require 'em-websocket'

HOST = '0.0.0.0'
PORT = 7401

MESSAGES = {
  in:  "%s пришел",
  out: "%s ушел",
  say: "%s сказал: %s",
  err: "Проблемы у %s: %s"
}

class ClientsManager
  
  @@clients = []
  
  def self.add(c)
    @@clients << c
    send MESSAGES[:in] % c.nick
  end
  
  def self.del(c)
    @@clients.delete c
  end
  
  def self.send(msg)
    @@clients.each do |c|
      c.ws.send msg
    end
  end
  
end

class Client < Struct.new(:nick, :ws)
  
  def listen(msg)
    msg.match(/^(\$?)(.*)$/) do |m|
      if m[1] == '/'
        ws.send m[2]
      else
        ClientsManager.send MESSAGES[:say] % [nick, msg]
      end
    end
  end
  
end

EventMachine.run do

  EventMachine::WebSocket.start(host: HOST, port: PORT) do |ws|
    
    c = Client.new('Client #' + rand(1000).to_s, ws)
  
    ws.onopen do
      ClientsManager.add c
    end

    ws.onclose do
      ClientsManager.del c
    end
    
    ws.onmessage do |msg|
      Client.listen msg
    end
    
    ws.onerror do |err|
      if err.kind_of?(EM::WebSocket::WebSocketError)
        ClientsManager.send MESSAGES[:err] % [c.nick, err.message]
      end
    end
    
  end
end

