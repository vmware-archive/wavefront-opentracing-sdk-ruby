# Wavefront Span.
#
# @author: Gangadharaswamy (gangadhar@vmware.com)

require 'concurrent'
require 'time'
require_relative 'span_context'

module WavefrontOpentracing
  # Wavefront Span
  class Span

    attr_reader :context, :operation_name, :start_time, :parents, :duration_time, :follows, :tags

    def initialize(tracer, operation_name, context, start_time, parents, follows, tags)
      # Construct Wavefront Span.
      # @param tracer [Tracer]: Tracer that create this span
      # @param operation_name [String]: Operation Name
      # @param context [WavefrontSpanContext]: Span Context
      # @param start_time [time.time()]: an explicit Span start time as a unix
      #                                  timestamp per
      # @param parents [uuid.UUID]: List of UUIDs of parents span
      # @param follows [uuid.UUID]: List of UUIDs of follows span
      # @param tags [Hash]: initial key:value tags (per set_tag) of the Span
      
      @tracer = tracer
      @context = context
      @operation_name = operation_name
      @start_time = start_time.to_i
      @duration_time = 0
      @parents = parents
      @follows = follows
      @tags = tags
      @finished = false
      @update_lock = Mutex.new
    end

    def set_tag(key, value)
      # Set tag of the span.
      # @param key [String] the key of the tag
      # @param value [String] the value of the tag. If it's not a String
      # it will be encoded with to_s

      @update_lock.synchronize do
        @tags.update( {key => value.to_s} ) unless is_blank(key) && value
      end
    end

    def set_baggage_item(key, value)
      # Replace span context with the updated dict of baggage.
      # @param key [String]: key of the baggage item
      # @param value [String]: value of the baggage item
      # @return [WavefrontSpan]: span itself

      context_with_baggage = @context.with_baggage_item(key, value)
      @update_lock.synchronize do
        @context = context_with_baggage 
      end
    end

    def get_baggage_item(key)
      # Get baggage item with given key.
      # @param key [String]: Key of baggage item
      # @return [String]: Baggage item value

      @context.get_baggage_item(key)
    end

    def set_operation_name(operation_name)
      # Update operation name.
      # @param operation_name [String] : Operation name.

      @update_lock.synchronize do
        @operation_name = operation_name
      end
    end

    def finish(end_time = nil)
      # Call finish to finish current span, and report it.
      # @param end_time [Float]: finish time, unix timestamp.

      if !end_time.nil?
        do_finish(end_time.to_i - @start_time)
      else
        do_finish(Time.now.to_i - @start_time)
      end
    end

    def do_finish(duration_time)
      # Mark span as finished and send it via reporter.
      # @param duration_time [Float]: Duration time in seconds
      # Thread.lock to be implemented

      @update_lock.synchronize do
        return if @finished

        @duration_time = duration_time
        @finished = true
      end
      @tracer.report_span(self)
    end

    def trace_id
      # Get trace id.
      # @return [uuid.UUID]: Wavefront Trace ID

      @context.trace_id
    end

    def span_id
      # Get span id.
      # @return [uuid.UUID]: Wavefront Span ID

      @context.span_id
    end

    def get_tags_as_list
      # Get tags in list format.
      # @return [List of pair] : list of tags

      return [] unless @tags

      tags_list = []
      @tags.each do |key, val|
        tags_list.push([key, val])
      end
      tags_list
    end

    def get_tags_as_map
      # Get tags in map format.
      # @return: tags in map format: {key: [list_of_val]}

      @tags
    end

    private

    def is_blank(value)
      # Check if the given value is blank or not
      # @return [Boolean] : true: if not nil and not empty
      #                     false: if nil or empty
      value.nil? || value.strip.empty? ? true : false
    end
  end
end
