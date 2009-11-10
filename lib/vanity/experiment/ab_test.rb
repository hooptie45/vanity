module Vanity
  module Experiment

    # The meat.
    class AbTest < Base
      def initialize(*args) #:nodoc:
        super
        @alternatives = [true, false]
      end

      # Chooses a value for this experiment.
      #
      # This method returns different values for different identity (see
      # #identify), and consistenly the same value for the same
      # expriment/identity pair.
      #
      # For example:
      #   color = experiment(:which_blue).choose
      def choose
        identity = identify
        alt = alternative_for(identity)
        redis.sadd key("alternative_#{alt}:participants"), identity
        @alternatives[alt]
      end

      # Records a conversion.
      #
      # For example:
      #   experiment(:which_blue).conversion!
      def conversion!
        identity = identify
        alt = alternative_for(identity)
        if redis.sismember(key("alternative_#{alt}:participants"), identity)
          redis.sadd key("alternative_#{alt}:converted"), identity
          redis.incr key("alternative_#{alt}:conversions")
        end
      end

      # Specifies alternative values for the A/B test. At least two values are required.
      # For example:
      #   experiment :background_color do
      #     alternatives "red", "blue", "orange"
      #   end
      def alternatives(*args)
        @alternatives = args unless args.empty?
        @alternatives
      end

      # True/false A/B test. For example:
      #   experiment :new_background do
      #     true_false
      #   end
      def true_false
        alternatives true, false
      end

      # Returns measurements for this experience: an hash with the key being the
      # alternative and the value being a hash of the participants and conversion counts.
      # For example:
      #   { :red=>{:participants=>15, :conversions=>5},
      #     :blue=>{:participants=>12, :conversions=>8} }
      def measure
        (0...@alternatives.count).inject({}) { |h,alt| h.update(@alternatives[alt] => {
          participants: redis.scard(key("alternative_#{alt}:participants")).to_i,
          converted: redis.scard(key("alternative_#{alt}:converted")).to_i,
          conversions: redis.get(key("alternative_#{alt}:conversions")).to_i
        }) }
      end

      def report
        results = measure
        alts = (0...@alternatives.count).map { |i|
          alt = @alternatives[i]
          "<dt>Option #{(65 + i).chr}</dt><dd><code>#{CGI.escape_html @alternatives[i].inspect}</code> viewed #{results[alt][:participants]} times, converted #{results[alt][:conversions]}<dd>"
        }
        %{<dl class="data">#{alts.join}</dl>}
      end

      def humanize
        "A/B Test" 
      end

      def save #:nodoc:
        fail "Experiment #{name} needs at least two alternatives" unless @alternatives && @alternatives.size >= 2
        super
      end

    private

      # Chooses an alternative for the identity and returns its index. This
      # method always returns the same alternative for a given experiment and
      # identity, and randomly distributed alternatives for each identity (in the
      # same experiment).
      def alternative_for(identity)
        Digest::MD5.hexdigest("#{name}/#{identity}").to_i(16) % @alternatives.count
      end

    end
  end
end
