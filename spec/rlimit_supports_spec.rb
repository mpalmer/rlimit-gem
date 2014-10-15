require_relative './spec_helper'
require 'rlimit'

describe RLimit do
	context "#supports?" do
		[RLimit::NOFILE, "NOFILE", :NOFILE, "RLIMIT_NOFILE", :RLIMIT_NOFILE].each do |res|
			it "OKs #{res.inspect}" do
				expect(RLimit.supports?(res)).to be(true)
			end
		end
		
		it "rejects a random symbol" do
			expect(RLimit.supports?(:OHAI)).to be(false)
		end
		
		it "rejects a random string" do
			expect(RLimit.supports?("OHAI")).to be(false)
		end
		
		it "rejects something really weird" do
			expect(RLimit.supports?(RLimit)).to be(false)
		end
	end
end
