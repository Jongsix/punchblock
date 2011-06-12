%w{
  timeout
  blather/client/dsl
  punchblock/core_ext/blather/stanza
  punchblock/core_ext/blather/stanza/presence
}.each { |f| require f }

module Punchblock
  module Protocol
    class Ozone
      class Connection < GenericConnection
        include Blather::DSL

        def initialize(options = {})
          super
          raise ArgumentError unless @username = options.delete(:username)
          raise ArgumentError unless options.has_key? :password
          @client_jid = Blather::JID.new @username

          setup @username, options.delete(:password)

          # This queue is used to synchronize between threads calling #write
          # and the connection-level responses they need to return from the
          # EventMachine loop.
          @result_queues = {}

          @callmap = {} # This hash maps call IDs to their XMPP domain.

          @command_id_to_iq_id = {}
          @iq_id_to_command = {}

          Blather.logger = options.delete(:wire_logger) if options.has_key?(:wire_logger)

          # FIXME: Force autoload events so they get registered properly
          [Event::Complete, Event::End, Event::Info, Event::Offer, Ref]
        end

        def write(call, msg)
          msg.connection = self
          jid = msg.is_a?(Command::Dial) ? @client_jid.domain : "#{call.call_id}@#{@callmap[call.call_id]}"
          iq = create_iq jid
          @logger.debug "Sending IQ ID #{iq.id} #{msg.inspect} to #{jid}" if @logger
          iq << msg
          @iq_id_to_command[iq.id] = msg
          @result_queues[iq.id] = Queue.new
          write_to_stream iq
          result = read_queue_with_timeout @result_queues[iq.id]
          @result_queues[iq.id] = nil # Shut down this queue
          # FIXME: Error handling
          raise result if result.is_a? Exception
          true
        end

        def run
          register_handlers
          EM.run { client.run }
        end

        def connected?
          client.connected?
        end

        def original_command_from_id(command_id)
          @iq_id_to_command[@command_id_to_iq_id[command_id]]
        end

        private

        def handle_presence(p)
          @logger.info "Receiving event for call ID #{p.call_id}" if @logger
          @callmap[p.call_id] = p.from.domain
          @logger.debug p.inspect if @logger
          event = p.event
          event.connection = self
          @event_queue.push event.is_a?(Event::Offer) ? Punchblock::Call.new(p.call_id, p.to, event.headers_hash) : event
        end

        def handle_iq(iq)
          # FIXME: Do we need to raise a warning if the domain changes?
          @callmap[iq.from.node] = iq.from.domain
          case iq.type
          when :result
            # Send this result to the waiting queue
            @logger.debug "Command #{iq.id} completed successfully" if @logger
            ref = iq.ozone_node
            @command_id_to_iq_id[ref.id] = iq.id if ref.is_a?(Ref)
            @result_queues[iq.id].push iq
          when :error
            # TODO: Example messages to handle:
            #------
            #<iq type="error" id="blather0016" to="usera@127.0.0.1/voxeo" from="15dce14a-778e-42f2-9ac4-501805ec0388@127.0.0.1">
            #  <answer xmlns="urn:xmpp:ozone:1"/>
            #  <error type="cancel">
            #    <item-not-found xmlns="urn:ietf:params:xml:ns:xmpp-stanzas"/>
            #  </error>
            #</iq>
            #------
            # FIXME: This should probably be parsed by the Protocol layer and return
            # a ProtocolError exception.
            if @result_queues.has_key?(iq.id)
              @result_queues[iq.id].push TransportError.new(iq)
            else
              # Un-associated transport error??
              raise TransportError, iq
            end
          else
            raise TransportError, iq
          end
        end

        def register_handlers
          # Push a message to the queue and the log that we connected
          when_ready do
            @event_queue.push connected
            @logger.info "Connected to XMPP as #{@username}" if @logger
          end

          # Read/handle call control messages. These are mostly just acknowledgement of commands
          iq { |msg| handle_iq msg }

          # Read/handle presence requests. This is how we get events.
          presence { |msg| handle_presence msg }
        end

        def create_iq(jid = nil)
          Blather::Stanza::Iq.new :set, jid || @call_id
        end

        def read_queue_with_timeout(queue, timeout = 3)
          begin
            Timeout::timeout(timeout) { queue.pop }
          rescue Timeout::Error => e
            e.to_s
          end
        end
      end
    end
  end
end