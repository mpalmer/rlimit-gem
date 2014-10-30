require 'ffi'
require 'ffi/tools/const_generator'

module RLimit
	# Exception raised when you attempt to raise the soft limit beyond the
	# hard limit.  This can happen either because you've specified both soft
	# and hard limits, and `soft > hard`, or because you're just specifying
	# the soft limit, but it is larger than the existing hard limit.
	#
	# If you wish to set the soft limit higher than the hard limit, you'll
	# need to raise the hard limit, too (which you can only do if you're
	# root, or have the CAP_SYS_RESOURCE capability).
	#
	class HardLimitExceeded < ::StandardError; end
	
	# You attempted to raise the hard limit on a resource, but you do not have
	# the appropriate permissions (typically you need to be root, or have the
	# CAP_SYS_RESOURCE capability).
	#
	class PermissionDenied < ::StandardError; end

	# Return an array of strings representing the available RLIMIT_* constants
	# that are available on your system.
	def self.resources
		@resources ||= (self.constants.map { |c| c.to_s } & POSSIBLE_RESOURCES).map { |c| "RLIMIT_#{c}" }
	end
	
	# Answer the question, "Does RLimit on my system support resource
	# `<X>`?".  You can specify `<X>` as either a string or a symbol, with or
	# without a leading `RLIMIT_`, or as an integer.  So any of the following
	# should work (assuming your system supports `RLIMIT_NOFILE`, and
	# `RLIMIT_NOFILE` is `7`):
	#
	#  * `RLimit.supports?(:NOFILE)`
	#  * `RLimit.supports?("NOFILE")`
	#  * `RLimit.supports?(:RLIMIT_NOFILE)`
	#  * `RLimit.supports?("RLIMIT_NOFILE")`
	#  * `RLimit.supports?(7)`
	#
	def self.supports?(res)
		begin
			!!get(res)
		rescue ArgumentError
			false
		end
	end

	# Retrieve the limits of the specified resource.
	#
	# `resource` can be any of the resource constants provided under `RLimit`,
	# or a symbol or string form of an `RLIMIT_*` constant (with or without
	# the leading `RLIMIT_`).
	#
	# `limit_type`, if specified, must be one of the symbols `:soft` or `:hard`.
	#
	# On success, this method returns one of the following:
	#
	#  * **If `limit_type` is specified:** the return value from this method
	#    will be a non-negative integer less than `2**32`, or the symbol
	#    `:unlimited` (guess what that means!).
	#
	#  * **If `limit_type` is not specified:** the return value will be a
	#    two-element array, consisting of the soft limit followed by the hard
	#    limit, each of which is either a non-negative integer less than
	#    `2**32`, or the symbol `:unlimited`.
	#
	# On error, this method can raise:
	#
	#  * `ArgumentError` if `resource` isn't a valid resource specifier, or
	#    `limit_type` isn't a valid limit type (`:soft` `:hard`, or
	#    unspecified).
	#
	#  * `RuntimeError` if one of a couple of "can't happen" events do
	#    actually occur.
	#
	def self.get(resource, limit_type = nil)
		resource = res_xlat(resource)

		rlim = RLimit::FFI::RLimitStruct.new

		if RLimit::FFI.getrlimit(resource, rlim.pointer) != 0
			raise_errno
		end
		
		case limit_type
			when nil   then [rlim_xlat(rlim[:rlim_cur]), rlim_xlat(rlim[:rlim_max])]
			when :soft then rlim_xlat(rlim[:rlim_cur])
			when :hard then rlim_xlat(rlim[:rlim_max])
			else raise ArgumentError,
			           "Unknown limit type #{limit_type.inspect}"
		end
	end

	# Change the limits of the specified resource.
	#
	# `resource` can be any of the resource constants provided under `RLimit`,
	# or a symbol or string form of an `RLIMIT_*` constant (with or without
	# the leading `RLIMIT_`).
	#
	# `soft_limit` and `hard_limit` can be a non-negative integer less than
	# `2**32`, the symbol `:unlimited`, or `nil` (meaning "no change").  Not
	# specifying `hard_limit` is equivalent to setting it to `nil` (hence only
	# the soft limit will be modified).
	#
	# Note that you can always *lower* a hard limit, but once lowered, it cannot
	# be raised again unless you have appropriate permissions.
	#
	# On success, this method returns `true`.
	#
	# On error, one of the following exceptions will be raised:
	#
	#  * `ArgumentError` if `resource` isn't a valid resource specifier, or
	#    either of `soft_limit` or `hard_limit` aren't valid values.
	#
	#  * `RLimit::HardLimitExceeded` if you attempt to set the soft limit to
	#    a value greater than the hard limit -- either because you set both
	#    limits, and `soft_limit > hard_limit`, or else you just tried to set
	#    the soft limit, but it was larger than the existing hard limit.
	#
	#  * `RLimit::PermissionDenied` if you tried to *raise* the hard limit
	#    without having the appropriate permissions to do so.
	#
	#  * `RuntimeError` if one of a couple of "can't happen" events do
	#    actually occur.  That means someone's going to have a bad day.
	#
	def self.set(resource, soft_limit, hard_limit = nil)
		resource = res_xlat(resource)

		soft_limit = rlim_xlat(soft_limit)
		hard_limit = rlim_xlat(hard_limit)

		unless hard_limit.nil? or
		       hard_limit.is_a?(Integer) or
		       hard_limit < 0 or
		       hard_limit >= 2**32
			raise ArgumentError,
			      "Invalid hard limit value: #{soft_limit.inspect}"
		end

		rlim = RLimit::FFI::RLimitStruct.new
		rlim[:rlim_cur], rlim[:rlim_max] = self.get(resource)
		
		if soft_limit
			rlim[:rlim_cur] = soft_limit
		end
		
		if hard_limit
			rlim[:rlim_max] = hard_limit
		end

		if rlim[:rlim_cur] > rlim[:rlim_max]
			raise RLimit::HardLimitExceeded,
			      "You cannot set the soft limit above #{rlim[:rlim_max]}"
		end
		
		if RLimit::FFI.setrlimit(resource, rlim.pointer) != 0
			raise_errno
		end

		true
	end

	#:nodoc:
	# Handle the translation between :unlimited and RLimit::RLIM_INFINITY
	# Since both are invalid *actual* values, we can use the same method
	# (and logic) to go in both directions.  We can also sanity-check
	# integer values here, too.  It's the all-in-one party method!
	def self.rlim_xlat(l)
		unless l.nil? or
		       l == :unlimited or
		       l.is_a?(Integer) or
		       l < 0 or
		       (l >= 2**32 and l != RLimit::RLIM_INFINITY)
			raise ArgumentError,
			      "Invalid soft limit value: #{soft_limit.inspect}"
		end

		if l == RLimit::RLIM_INFINITY
			:unlimited
		elsif l == :unlimited
			RLimit::RLIM_INFINITY
		else
			l
		end
	end
	
	#:nodoc:
	# Take something that may or may not be a valid-looking resource
	# specifier, and turn it into an integer that could well be a valid valid
	# for `{get,set}rlimit`.  Raise all sorts of ArgumentError if we can't
	# work out what's going on.
	def self.res_xlat(r)
		err = "Invalid rlimit resource specifier #{r.inspect}"
		
		unless r.is_a? Integer
			r = r.to_s.gsub(/^RLIMIT_/, '').to_sym
			begin
				if self.const_defined?(r)
					r = self.const_get(r)
				else
					raise ArgumentError, err
				end
			rescue NameError
				raise ArgumentError, err
			end
		end
		
		unless r.is_a? Integer
			raise ArgumentError, err
		end

		r
	end

	#:nodoc:
	# Inspect errno and raise the appropriate exception.
	def self.raise_errno
		case ::FFI.errno
		when Errno::EFAULT::Errno
			raise RuntimeError, 
			      "getrlimit detected pointer outside of addressable space.  WTF?"
		when Errno::EINVAL::Errno
			raise ArgumentError,
			      "Invalid rlimit resource specifier #{resource.inspect}"
			when Errno::EPERM::Errno
				raise RLimit::PermissionDenied,
				      "You do not have permission to raise hard limits"
		else
			raise RuntimeError,
			      "Unknown errno returned: #{::FFI.errno}"
		end
	end
	
	# The FFI-related internals of our little shindig.  Here be dragons.
	#:nodoc:all
	module FFI  #:nodoc:all
		extend ::FFI::Library
		ffi_lib ::FFI::Library::LIBC
		
		def self.rlim_t
			@rlim_t ||= ::FFI.find_type(:rlim_t)
		end
		
		class RLimitStruct < ::FFI::Struct
			layout :rlim_cur, RLimit::FFI.rlim_t,
			       :rlim_max, RLimit::FFI.rlim_t
		end

		attach_function :setrlimit, [ :int, :pointer ], :int
		attach_function :getrlimit, [ :int, :pointer ], :int
	end

	#:nodoc:
	# This is the list of all *possible* resources that can be defined; it
	# isn't everything that's available on this system.  It's been
	# constructed by grovelling through the manpages for `setrlimit`(2) on a
	# number of different OSes; additions welcomed.
	POSSIBLE_RESOURCES = %w{
		AS
		CORE
		CPU
		DATA
		FSIZE
		LOCKS
		MEMLOCK
		MSGQUEUE
		NICE
		NOFILE
		NPROC
		RSS
		RTPRIO
		RTTIME
		SBSIZE
		SIGPENDING
		STACK
		SWAP
		NPTS
	}

	cg = ::FFI::ConstGenerator.new("rlimit") do |cg|
		cg.include("sys/resource.h")
		cg.const("RLIM_INFINITY", '%llu')
		
		POSSIBLE_RESOURCES.each do |r|
			cg.const("RLIMIT_#{r}", nil, '', r)
		end
	end
	
	eval cg.to_ruby
end
