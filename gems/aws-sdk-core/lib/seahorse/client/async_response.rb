module Seahorse
  module Client
    class AsyncResponse

      def initialize(options = {})
        @response = Response.new(context: options[:context])
        @stream = options[:stream]
        @stream_mutex = options[:stream_mutex]
        @close_condition = options[:close_condition]
        @sync_queue = options[:sync_queue]
      end

      def context
        @response.context
      end

      def error
        @response.error
      end

      def on(range, &block)
        @response.on(range, &block)
        self
      end

      def on_complete(&block)
        @response.on_complete(&block)
        self
      end

      def wait
        if error && context.config.raise_response_errors
          raise error
        elsif @stream
          # have a sync signal that #signal can be blocked on
          # else, if #signal is called before #wait
          # will be waiting for a signal never arrives
          @sync_queue << "sync_signal"
          # now #signal is unlocked for
          # signaling close condition when ready
          @stream_mutex.synchronize {
            @close_condition.wait(@stream_mutex)
          }
          _kill_input_thread
          @response
        end
      end

      def join!
        if error && context.config.raise_response_errors
          raise error
        elsif @stream
          @stream.close
          _kill_input_thread
          @response
        end
      end

      private

      def _kill_input_thread
        if thread = context[:input_signal_thread]
          Thread.kill(thread)
        end
        nil
      end

    end
  end
end
