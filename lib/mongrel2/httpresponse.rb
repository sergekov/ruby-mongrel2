#!/usr/bin/ruby

require 'time'

require 'mongrel2/response' unless defined?( Mongrel2::Response )
require 'mongrel2/mixins'
require 'mongrel2/constants'


# The Mongrel2 HTTP Response class.
class Mongrel2::HTTPResponse < Mongrel2::Response
	include Mongrel2::Loggable,
	        Mongrel2::Constants

	# The format for building valid HTTP responses
	STATUS_LINE_FORMAT = "HTTP/1.1 %03d %s".freeze

	# The default status
	DEFAULT_HTTP_STATUS = 200

	# A network End-Of-Line
	EOL = "\r\n".freeze

	# The default content type
	DEFAULT_CONTENT_TYPE = 'application/octet-stream'.freeze


	### Set up a few things specific to HTTP responses
	def initialize( sender_id, conn_id, body='', headers={} ) # :notnew:
		if body.is_a?( Hash )
			headers = body
			body = ''
		end

		super( sender_id, conn_id, body )

		@headers = Mongrel2::Table.new( headers )
		@status = nil
		self.reset
	end


	######
	public
	######

	# The response headers (a Mongrel2::Table)
	attr_reader :headers

	# The HTTP status code
	attr_accessor :status


	### Stringify the response
	def to_s
		return [
			self.status_line,
			self.header_data,
			self.body
		].join( "\r\n" )
	end


	### Send the response status to the client
	def status_line
		self.log.warn "Building status line for unset status" if self.status.nil?

		st = self.status || DEFAULT_HTTP_STATUS
		return STATUS_LINE_FORMAT % [ st, HTTP::STATUS_NAME[st] ]
	end


	### Returns true if the response is ready to be sent to the client.
	def handled?
		return ! @status.nil?
	end
	alias_method :is_handled?, :handled?


	### Return the numeric category of the response's status code (1-5)
	def status_category
		return 0 if self.status.nil?
		return (self.status / 100).ceil
	end


	### Return true if response is in the 1XX range
	def status_is_informational?
		return self.status_category == 1
	end

	### Return true if response is in the 2XX range
	def status_is_successful?
		return self.status_category == 2
	end


	### Return true if response is in the 3XX range
	def status_is_redirect?
		return self.status_category == 3
	end


	### Return true if response is in the 4XX range
	def status_is_clienterror?
		return self.status_category == 4
	end


	### Return true if response is in the 5XX range
	def status_is_servererror?
		return self.status_category == 5
	end


	### Return the current response Content-Type.
	def content_type
		return self.headers[ :content_type ]
	end


	### Set the current response Content-Type.
	def content_type=( type )
		return self.headers[ :content_type ] = type
	end


	### Clear any existing headers and body and restore them to their defaults
	def reset
		@headers.clear
		@headers[:server] = Mongrel2.version_string( true )
		@status = nil
		@body = ''

		return true
	end


	### Return the current response header as a valid HTTP string.
	def header_data
		self.headers[:date] ||= Time.now.httpdate
		self.headers[:content_length] ||= self.get_content_length

		return self.headers.to_s
	end


	### Get the length of the body, either by calling its #length method if it has
	### one, or using #seek and #tell if it implements those. If neither of those are
	### possible, an exception is raised.
	def get_content_length
		if @body.respond_to?( :length )
			return @body.length
		elsif @body.respond_to?( :seek ) && @body.respond_to?( :tell )
			starting_pos = @body.tell
			@body.seek( 0, IO::SEEK_END )
			length = @body.tell - starting_pos
			@body.seek( starting_pos, IO::SEEK_SET )

			return length
		else
			raise Mongrel2::ResponseError,
				"No way to calculate the content length of the response (a %s)." %
				[ @body.class.name ]
		end
	end


	### Set the Connection header to allow pipelined HTTP.
	def keepalive=( value )
		self.headers[:connection] = value ? 'keep-alive' : 'close'
	end
	alias_method :pipelining_enabled=, :keepalive=


	### Returns +true+ if the response has pipelining enabled.
	def keepalive?
		ka_header = self.headers[:connection]
		return !ka_header.nil? && ka_header =~ /keep-alive/i
		return false
	end
	alias_method :pipelining_enabled?, :keepalive?

end # class Mongrel2::Response

# vim: set nosta noet ts=4 sw=4:

