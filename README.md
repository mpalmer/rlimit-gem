Ever needed to adjust system limits in Ruby?  If so, congratulations! 
You're in an infinitesimally-small minority.  But at least now you can do
it.  Unless you're on Windows.  Then you're still on your own.


# Installation

It's a gem:

    gem install rlimit

If you're the sturdy type that likes to run from git:

    rake build; gem install pkg/rlimit-<whatever>.gem

Or, if you've eschewed the convenience of Rubygems, then you presumably know
what to do already.


# Usage

There are two main methods available to you.  To read a resource limit, use
`RLimit.get`, passing it one of the available `RLimit::<TYPE>` constants
(more on that later), and optionally one of the symbols `:hard` or `:soft`:

    >> RLimit.get(RLimit::NOFILE)
    => [1024, 65536]

    >> RLimit.get(RLimit::NOFILE, :soft)
    => 1024
    
    >> RLimit.get(RLimit::NOFILE, :hard)
    => 65536
    
    >> RLimit.get(RLimit::CPU)
    => [:unlimited, :unlimited]
    
    >> RLimit.get(RLimit::NOFILE, :lolidunno)
    ArgumentError: Unknown limit type :lolidunno
    
    >> RLimit.get("ohai!")
    ArgumentError: Invalid rlimit resource specifier "ohai!"

A limit value is represented as either a non-negative integer, or the symbol
`:unlimited`, to indicate that there is no limit on the resource.  There are
two possible return value "patterns", too -- if you don't specify a limit
type, you get back a two-element array `[<soft>, <hard>]`, whereas if you
ask for one specific type of limit, you get back a scalar.  If you're
adventurous enough to try and pass an invalid argument, well, you get an
`ArgumentError` for your troubles.

To set a resource limit, you've got `RLimit.set`:

    # Set just a soft limit
    >> RLimit.set(RLimit::NOFILE, 64)
    => true
    
    # Set just a hard limit
    >> RLimit.set(RLimit::NOFILE, nil, 128)
    => true
    
    # Set both soft and hard limits
    >> RLimit.set(RLimit::NOFILE, 64, 128)
    => true
    
    # Set an unlimited soft limit
    >> RLimit.set(RLimit::CORE, :unlimited)
    => true

    # Try to increase a hard limit when not root
    >> RLimit.set(RLimit::NOFILE, nil, 1048576)
    RLimit::PermissionDenied: You do not have permission to raise hard limits
    
    # Try to increase a soft limit above the hard limit
    >> RLimit.set(RLimit::NOFILE, 128, 64)
    RLimit::HardLimitExceeded: You cannot raise the soft limit above 64

Hopefully that should all be fairly self-explanatory.  If not, well, there's
more detailed documentation in the RDoc.


## Available resource types

There is no guaranteed set of resource types which are available on all
systems.  To discover what is available on your system, call
`RLimit.resources`, this will return an array containing the constants that
are defined.  You should reference `setrlimit`(2) for your system to
determine exactly what they all mean.

If you wish to determine at runtime whether RLimit on your system supports a
particular resource, you can use `RLimit.supports?("RLIMIT_<res>")` -- or
just try to work with it anyway and rescue `ArgumentError`....


## Soft and Hard Limits

The "soft" limit for an rlimit is the value that a process is currently
restricted to; an attempt to exceed that limit will result in some sort of
failure.  However, a process can itself request to increase the value of a limit
up to the "hard" limit.  Only a process owned by `root` (or which has been
granted the `CAP_SYS_RESOURCE` capability, on systems that support such a
thing) can increase the hard limit.


# Contributing

Bug reports should be sent to the [Github issue
tracker](https://github.com/mpalmer/rlimit-gem/issues), or
[e-mailed](mailto:theshed+rlimit@hezmatt.org).  Patches can be sent as a
Github pull request, or [e-mailed](mailto:theshed+rlimit@hezmatt.org).
