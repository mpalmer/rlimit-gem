require_relative './spec_helper'
require 'rlimit'

describe RLimit do
	context "#set" do
		context "via getrlimit" do
			before :each do
				expect(RLimit::FFI).
				  to receive(:getrlimit).
				  with(any_args()) do |res, rlim_ptr|
				    expect(res).to eq(RLimit::NOFILE)
				    expect(rlim_ptr).to be_an(::FFI::MemoryPointer)
				    rlim = RLimit::FFI::RLimitStruct.new(rlim_ptr)
				    rlim[:rlim_cur] = 1024
				    rlim[:rlim_max] = 1048576
				  end.and_return(0)
			end
				
			it "handles both limits being set" do
				expect(RLimit::FFI).
				  to receive(:setrlimit).
				  with(any_args()) do |res, rlim_ptr|
				    expect(res).to eq(RLimit::NOFILE)
				    expect(rlim_ptr).to be_an(::FFI::MemoryPointer)
				    rlim = RLimit::FFI::RLimitStruct.new(rlim_ptr)
				    expect(rlim[:rlim_cur]).to eq(4096)
				    expect(rlim[:rlim_max]).to eq(65536)
				  end.and_return(0)

				expect(RLimit.set(RLimit::NOFILE, 4096, 65536)).to be(true)
			end

			it "handles just the soft limit changing" do
				expect(RLimit::FFI).
				  to receive(:setrlimit).
				  with(any_args()) do |res, rlim_ptr|
				    expect(res).to eq(RLimit::NOFILE)
				    expect(rlim_ptr).to be_an(::FFI::MemoryPointer)
				    rlim = RLimit::FFI::RLimitStruct.new(rlim_ptr)
				    expect(rlim[:rlim_cur]).to eq(4096)
				    expect(rlim[:rlim_max]).to eq(1048576)
				  end.and_return(0)

				expect(RLimit.set(RLimit::NOFILE, 4096)).to be(true)
			end

			["NOFILE", "RLIMIT_NOFILE", :NOFILE, :RLIMIT_NOFILE].each do |res|
				it "handles the resource form #{res.inspect}" do
					expect(RLimit::FFI).
					  to receive(:setrlimit).
					  with(any_args()) do |res, rlim_ptr|
					    expect(res).to eq(RLimit::NOFILE)
					    expect(rlim_ptr).to be_an(::FFI::MemoryPointer)
					    rlim = RLimit::FFI::RLimitStruct.new(rlim_ptr)
					    expect(rlim[:rlim_cur]).to eq(4096)
					    expect(rlim[:rlim_max]).to eq(1048576)
					  end.and_return(0)

					expect(RLimit.set(res, 4096)).to be(true)
				end
			end

			it "handles just the hard limit changing" do
				expect(RLimit::FFI).
				  to receive(:setrlimit).
				  with(any_args()) do |res, rlim_ptr|
				    expect(res).to eq(RLimit::NOFILE)
				    expect(rlim_ptr).to be_an(::FFI::MemoryPointer)
				    rlim = RLimit::FFI::RLimitStruct.new(rlim_ptr)
				    expect(rlim[:rlim_cur]).to eq(1024)
				    expect(rlim[:rlim_max]).to eq(65536)
				  end.and_return(0)

				expect(RLimit.set(RLimit::NOFILE, nil, 65536)).to be(true)
			end
			
			it "handles the limit being :unlimited" do
				expect(RLimit::FFI).
				  to receive(:setrlimit).
				  with(any_args()) do |res, rlim_ptr|
				    expect(res).to eq(RLimit::NOFILE)
				    expect(rlim_ptr).to be_an(::FFI::MemoryPointer)
				    rlim = RLimit::FFI::RLimitStruct.new(rlim_ptr)
				    expect(rlim[:rlim_cur]).to eq(RLimit::RLIM_INFINITY)
				    expect(rlim[:rlim_max]).to eq(RLimit::RLIM_INFINITY)
				  end.and_return(0)

				expect(RLimit.set(RLimit::NOFILE, :unlimited, :unlimited)).to be(true)
			end

			it "freaks out if the soft limit is greater than the existing hard limit" do
				expect { RLimit.set(RLimit::NOFILE, 1048577) }.
				  to raise_error(
				       RLimit::HardLimitExceeded,
				       "You cannot set the soft limit above 1048576"
				     )
			end

			it "freaks out if the soft limit is greater than the hard limit specified" do
				expect { RLimit.set(RLimit::NOFILE, 65536, 4096) }.
				  to raise_error(
				       RLimit::HardLimitExceeded,
				       "You cannot set the soft limit above 4096"
				     )
			end
			
			it "freaks out when setrlimit sends back EPERM" do
				expect(RLimit::FFI).
				  to receive(:setrlimit).
				  with(any_args()) do |res, rlim_ptr|
				    expect(res).to eq(RLimit::NOFILE)
				    expect(rlim_ptr).to be_an(::FFI::MemoryPointer)
				  end.and_return(-1)
				
				expect(::FFI).to receive(:errno).and_return(Errno::EPERM::Errno)
				
				expect { RLimit.set(RLimit::NOFILE, nil, 2000000) }.
				  to raise_error(
				       RLimit::PermissionDenied,
				       "You do not have permission to raise hard limits"
				     )
			end
		end

		context "ArgumentError cases" do
			it "raises ArgumentError on an unknown resource type" do
				expect { RLimit.set("ohai!", 42) }.to raise_error(ArgumentError)
			end

			it "raises ArgumentError on a non-integer soft limit" do
				expect { RLimit.set(RLimit::NOFILE, :lolidunno) }.to raise_error(ArgumentError)
			end

			it "raises ArgumentError on a non-integer hard limit" do
				expect { RLimit.set(RLimit::NOFILE, 42, :lolidunno) }.to raise_error(ArgumentError)
			end
		end
	end
end
