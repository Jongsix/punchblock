# encoding: utf-8

module Punchblock
  module Component
    class Input < ComponentNode
      register :input, :input

      ##
      # Create a input command
      #
      # @param [Hash] options
      # @option options [Grammar, Hash] :grammar the grammar to activate
      # @option options [Integer, optional] :max_silence the amount of time in milliseconds that an input command will wait until considered that a silence becomes a NO-MATCH
      # @option options [Float, optional] :min_confidence with which to consider a response acceptable
      # @option options [Symbol, optional] :mode by which to accept input. Can be :speech, :dtmf or :any
      # @option options [String, optional] :recognizer to use for speech recognition
      # @option options [String, optional] :terminator by which to signal the end of input
      # @option options [Float, optional] :sensitivity Indicates how sensitive the interpreter should be to loud versus quiet input. Higher values represent greater sensitivity.
      # @option options [Integer, optional] :initial_timeout Indicates the amount of time preceding input which may expire before a timeout is triggered.
      # @option options [Integer, optional] :inter_digit_timeout Indicates (in the case of DTMF input) the amount of time between input digits which may expire before a timeout is triggered.
      #
      # @return [Command::Input] a formatted Rayo input command
      #
      # @example
      #    input :grammar     => {:value => '[5 DIGITS]', :content_type => 'application/grammar+voxeo'},
      #          :mode        => :speech,
      #          :recognizer  => 'es-es'
      #
      #    returns:
      #      <input xmlns="urn:xmpp:rayo:input:1" mode="speech" recognizer="es-es">
      #        <grammar content-type="application/grammar+voxeo">[5 DIGITS]</choices>
      #      </input>
      #
      def self.new(options = {})
        super().tap do |new_node|
          options.each_pair { |k,v| new_node.send :"#{k}=", v }
        end
      end

      ##
      # @return [Integer] the amount of time in milliseconds that an input command will wait until considered that a silence becomes a NO-MATCH
      #
      def max_silence
        read_attr :'max-silence', :to_i
      end

      ##
      # @param [Integer] other the amount of time in milliseconds that an input command will wait until considered that a silence becomes a NO-MATCH
      #
      def max_silence=(other)
        write_attr :'max-silence', other, :to_i
      end

      ##
      # @return [Float] Confidence with which to consider a response acceptable
      #
      def min_confidence
        read_attr 'min-confidence', :to_f
      end

      ##
      # @param [Float] min_confidence with which to consider a response acceptable
      #
      def min_confidence=(min_confidence)
        write_attr 'min-confidence', min_confidence, :to_f
      end

      ##
      # @return [Symbol] mode by which to accept input. Can be :speech, :dtmf or :any
      #
      def mode
        read_attr :mode, :to_sym
      end

      ##
      # @param [Symbol] mode by which to accept input. Can be :speech, :dtmf or :any
      #
      def mode=(mode)
        write_attr :mode, mode
      end

      ##
      # @return [String] recognizer to use for speech recognition
      #
      def recognizer
        read_attr :recognizer
      end

      ##
      # @param [String] recognizer to use for speech recognition
      #
      def recognizer=(recognizer)
        write_attr :recognizer, recognizer
      end

      ##
      # @return [String] terminator by which to signal the end of input
      #
      def terminator
        read_attr :terminator
      end

      ##
      # @param [String] terminator by which to signal the end of input
      #
      def terminator=(terminator)
        write_attr :terminator, terminator
      end

      ##
      # @return [Float] Indicates how sensitive the interpreter should be to loud versus quiet input. Higher values represent greater sensitivity.
      #
      def sensitivity
        read_attr :sensitivity, :to_f
      end

      ##
      # @param [Float] other Indicates how sensitive the interpreter should be to loud versus quiet input. Higher values represent greater sensitivity.
      #
      def sensitivity=(other)
        write_attr :sensitivity, other, :to_f
      end

      ##
      # @return [Integer] Indicates the amount of time preceding input which may expire before a timeout is triggered.
      #
      def initial_timeout
        read_attr :'initial-timeout', :to_i
      end

      ##
      # @param [Integer] timeout Indicates the amount of time preceding input which may expire before a timeout is triggered.
      #
      def initial_timeout=(other)
        write_attr :'initial-timeout', other, :to_f
      end

      ##
      # @return [Integer] Indicates (in the case of DTMF input) the amount of time between input digits which may expire before a timeout is triggered.
      #
      def inter_digit_timeout
        read_attr :'inter-digit-timeout', :to_i
      end

      ##
      # @param [Integer] timeout Indicates (in the case of DTMF input) the amount of time between input digits which may expire before a timeout is triggered.
      #
      def inter_digit_timeout=(other)
        write_attr :'inter-digit-timeout', other, :to_i
      end

      ##
      # @return [Array<Grammar>] the grammars to activate
      #
      def grammars
        nodes = find 'ns:grammar', :ns => self.class.registered_ns
        nodes.map { |node| Grammar.new node }
      end

      ##
      # @param [Hash] other
      # @option other [String] :content_type the document content type
      # @option other [String] :value the grammar doucment
      # @option other [String] :url the url from which to fetch the grammar
      #
      def grammar=(other)
        self.grammars = [other].compact
      end

      ##
      # @param[Array<Hash>] others
      # @see #grammar= for hash format
      #
      def grammars=(others)
        remove_children :grammar
        others.each do |other|
          grammar = Grammar.new(other) unless other.is_a?(Grammar)
          self << grammar
        end
      end

      def inspect_attributes # :nodoc:
        [:mode, :terminator, :recognizer, :initial_timeout, :inter_digit_timeout, :sensitivity, :min_confidence, :grammars] + super
      end

      class Grammar < RayoNode
        ##
        # @param [Hash] options
        # @option options [String] :content_type the document content type
        # @option options [String] :value the grammar document
        # @option options [String] :url the url from which to fetch the grammar
        #
        def self.new(options = {})
          super(:grammar).tap do |new_node|
            case options
            when Nokogiri::XML::Node
              new_node.inherit options
            when Hash
              new_node.content_type = options[:content_type]
              new_node.value = options[:value]
              new_node.url = options[:url]
            end
          end
        end

        ##
        # @return [String] the document content type
        #
        def content_type
          read_attr 'content-type'
        end

        ##
        # @param [String] content_type Defaults to GRXML
        #
        def content_type=(content_type)
          return unless content_type
          write_attr 'content-type', content_type
        end

        ##
        # @return [String, RubySpeech::GRXML::Grammar] the grammar document
        def value
          return nil unless content.present?
          if grxml?
            RubySpeech::GRXML.import content
          else
            content
          end
        end

        ##
        # @param [String, RubySpeech::GRXML::Grammar] value the grammar document
        def value=(value)
          return unless value
          self.content_type = grxml_content_type unless self.content_type
          if grxml? && !value.is_a?(RubySpeech::GRXML::Element)
            value = RubySpeech::GRXML.import value
          end
          Nokogiri::XML::Builder.with(self) do |xml|
            xml.cdata " #{value} "
          end
        end

        ##
        # @return [String] the URL from which the fetch the grammar
        #
        def url
          read_attr 'url'
        end

        ##
        # @param [String] other the URL from which the fetch the grammar
        #
        def url=(other)
          write_attr 'url', other
        end

        def inspect_attributes # :nodoc:
          [:content_type, :value, :url] + super
        end

        private

        def grxml_content_type
          'application/srgs+xml'
        end

        def grxml?
          content_type == grxml_content_type
        end
      end # Choices

      class Complete
        class Match < Event::Complete::Reason
          register :match, :input_complete

          def nlsml
            @nlsml ||= RubySpeech.parse result_node.to_xml
          end

          def nlsml=(other)
            self << other.root.to_xml
          end

          def mode
            nlsml.best_interpretation[:input][:mode]
          end

          def confidence
            nlsml.best_interpretation[:confidence]
          end

          def utterance
            nlsml.best_interpretation[:input][:content]
          end

          def interpretation
            nlsml.best_interpretation[:instance]
          end

          def inspect_attributes # :nodoc:
            [:name, :nlsml] + super
          end

          private

          def result_node
            at_xpath 'ns:result', 'ns' => 'http://www.w3c.org/2000/11/nlsml' or raise "Couldn't find the NLSML node"
          end
        end

        class NoMatch < Event::Complete::Reason
          register :nomatch, :input_complete
        end

        NoInput = Module.new

        class InitialTimeout < Event::Complete::Reason
          include NoInput
          register :'initial-timeout', :input_complete
        end

        class InterDigitTimeout < Event::Complete::Reason
          include NoInput
          register :'inter-digit-timeout', :input_complete
        end

        class MaxSilence < Event::Complete::Reason
          include NoInput
          register :'max-silence', :input_complete
        end

        class MinConfidence < Event::Complete::Reason
          include NoInput
          register :'min-confidence', :input_complete
        end
      end # Complete
    end # Input
  end # Component
end # Punchblock
