module IRuby
  class Kernel
    attr_reader :pub_socket, :session

    # from minad/iruby
    def run
      send_status('starting')
      while @running
        ident, msg = @session.recv(@reply_socket, 0)

        STDERR.puts("received.:" + msg.to_s)

        type = msg[:header]['msg_type']
        if type =~ /_request\Z/ && respond_to?(type)
          send(type, ident, msg)
        elsif type =~ /comm/
          send(type, ident, msg)
        else
          STDERR.puts "Unknown message type: #{msg[:header]['msg_type']} #{msg.inspect}"
        end
      end
    end

    def comm_open(ident, msg)
      comm_id = msg[:content]["comm_id"]
      comm = Comm.new(msg[:content]["target_name"], comm_id)
      @comm[comm_id] = comm
    end

    def comm_msg(ident, msg)
      comm_id = msg[:content]["comm_id"]
      @comm[comm_id].handle_msg(msg[:content]["data"])
    end

    def comm_close(ident, msg)
      comm_id = msg[:content]["comm_id"]
      @comm[comm_id].handle_close
      @comm.delete(comm_id)
    end

    def register_comm(comm_id, comm)
      @comm[comm_id] = comm
    end
  end

  class Comm
    def initialize(target_name, comm_id=SecureRandom.hex(16))
      @comm_id = comm_id
      @target_name = target_name
      @session = Kernel.instance.session
      @pub_socket = Kernel.instance.pub_socket
    end

    def open(data={})
      content = {
        comm_id: @comm_id,
        data: data,
        target_name: @target_name
      }
      @session.send(@pub_socket, "comm_open", content)
    end

    def send(data={})
      content = {
        comm_id: @comm_id,
        data: data
      }
      @session.send(@pub_socket, 'comm_msg', content)
    end

    def close(data={})
      content = {
        comm_id: @comm_id,
        data: data
      }
      @session.send(@pub_socket, 'comm_close', content)
    end

    def on_open(callback)
      @open_callback = callback
    end

    def on_msg(callback)
      @msg_callback = callback
    end

    def on_close(callback)
      @close_callback = callback
    end

    def handle_open(msg)
      @open_callback.call(msg) unless @open_callback.nil?
    end

    def handle_msg(msg)
      @msg_callback.call(msg) unless @msg_callback.nil?
    end

    def handle_close(msg)
      @close_callback.call(msg) unless @close_callback.nil?
    end
  end

  class Widget
    def initialize(view_name, target_name="WidgetModel")
      @model_id = SecureRandom.hex(16).upcase
      @comm = Comm.new(target_name, @model_id)
      Kernel.register_comm(@comm)
      @comm.open

      content = {
        method: "update",
        state: {
          _view_name: view_name,
          visible: true,
          _css: {},
          description: "",
          msg_throttle: 3,
          disabled: false
        }
      }

      @comm.send(content)
    end

    # send custom message to front-end
    def send(content)
      @comm.send({method: "custom", content: content})
    end

    def on_msg(callback)
      @msg_callback = callback
    end

    def to_iruby
      @comm.send({method: "display"})
    end

    # msg ex: {"method" => "", "content"=> ""}
    def handle_msg(msg)
      if msg["method"] == "custom"
        @msg_callback.call(msg["content"])
      else
        # not implemented
      end
    end
  end
end
