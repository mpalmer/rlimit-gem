require_relative './spec_helper'
require 'rlimit'

describe RLimit do
	context "#get" do
		it "sends back two values for one-arg call" do
			rv = RLimit.get(RLimit::NOFILE)
			expect(rv).to be_an(Array)
			expect(rv[0]).to be_an(Integer)
			expect(rv[1]).to be_an(Integer)
		end

		it "sends back one arg for a soft-limit request" do
			expect(RLimit.get(RLimit::NOFILE, :soft)).to be_an(Integer)
		end
		
		it "sends back one arg for a hard-limit request" do
			expect(RLimit.get(RLimit::NOFILE, :hard)).to be_an(Integer)
		end
		
		it "raises ArgumentError on an unknown resource type" do
			expect { RLimit.get("ohai!") }.to raise_error(ArgumentError)
		end

		it "raises ArgumentError on an unknown limit type" do
			expect { RLimit.get(RLimit::NOFILE, :lolidunno) }.to raise_error(ArgumentError)
		end
		
		it "handles an unprefixed string" do
			expect(RLimit.get("NOFILE", :soft)).to eq(RLimit.get(RLimit::NOFILE, :soft))
		end
		
		it "handles a prefixed string" do
			expect(RLimit.get("RLIMIT_NOFILE", :soft)).to eq(RLimit.get(RLimit::NOFILE, :soft))
		end
		
		it "handles an unprefixed symbol" do
			expect(RLimit.get(:NOFILE, :soft)).to eq(RLimit.get(RLimit::NOFILE, :soft))
		end
		
		it "handles a prefixed symbol" do
			expect(RLimit.get(:RLIMIT_NOFILE, :soft)).to eq(RLimit.get(RLimit::NOFILE, :soft))
		end
		
		it "sends back :unlimited when getrlimit returns RLIM_INFINITY" do
			expect(RLimit::FFI).
			  to receive(:getrlimit).
			  # I'm using any_args() here, and then checking the types in the
			  # block, because there's a buggy interaction with RSpec (3.1.3,
			  # at least) and FFI::MemoryPointer (1.9.3, at least) which causes
			  # any ArgumentMatcher to fail to match, because
			  # FFI::MemoryPointer#== doesn't like getting compared with
			  # something else.  I think the bug's in RSpec, but I'm not sure
			  # enough to file a bug.  So we just work around it, because even
			  # if I *did* submit a bug, we'd have to work around it anyway to
			  # get the tests to pass.
			  with(any_args()) do |resource, rlim_ptr|
			    expect(resource).to eq(RLimit::NOFILE)
			    expect(rlim_ptr).to be_an(FFI::MemoryPointer)
			    rlim = RLimit::FFI::RLimitStruct.new(rlim_ptr)
			    rlim[:rlim_cur] = 1024
			    rlim[:rlim_max] = RLimit::RLIM_INFINITY
			  end.and_return(0)
			
			expect(RLimit.get(RLimit::NOFILE, :hard)).to eq(:unlimited)
		end
	end
end
