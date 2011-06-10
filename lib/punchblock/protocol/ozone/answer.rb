module Punchblock
  module Protocol
    module Ozone
      ##
      # An Ozone answer message.  This is equivalent to a SIP "200 OK"
      #
      # @example
      #    Answer.new.to_xml
      #
      #    returns:
      #        <answer xmlns="urn:xmpp:ozone:1"/>
      class Answer < Command
        register :answer, :core

        include HasHeaders

        # Overrides the parent to ensure a answer node is created
        # @private
        def self.new(options = {})
          super().tap do |new_node|
            new_node.headers = options[:headers]
          end
        end
      end # Answer
    end # Ozone
  end # Protocol
end # Punchblock