require_relative './spec_helper'
require 'rlimit'

describe RLimit do
	context "#resources" do
		it "has a common RLIMIT constant" do
			expect(RLimit.resources).to include("RLIMIT_NOFILE")
		end

		it "doesn't have a non-existent RLIMIT constant" do
			expect(RLimit.resources).to_not include("RLIMIT_WTFISTHIS")
		end
		
		it "doesn't have RLIM_INFINITY" do
			expect(RLimit.resources).to_not include("RLIMIT_RLIM_INFINITY")
			expect(RLimit.resources).to_not include("RLIM_INFINITY")
		end
		
		it "doesn't have our exceptions" do
			expect(RLimit.resources).to_not include("RLIMIT_PermissionDenied")
			expect(RLimit.resources).to_not include("PermissionDenied")
			expect(RLimit.resources).to_not include("RLIMIT_HardLimitExceeded")
			expect(RLimit.resources).to_not include("HardLimitExceeded")
		end
	end
end
