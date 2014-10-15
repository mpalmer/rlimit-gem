require 'git-version-bump'

Gem::Specification.new do |s|
	s.name = "rlimit"

	s.version = GVB.version
	s.date    = GVB.date

	s.platform = Gem::Platform::RUBY

	s.homepage = "http://theshed.hezmatt.org/rlimit"
	s.summary = "Retrieve and adjust rlimits"
	s.authors = ["Matt Palmer"]

	s.extra_rdoc_files = ["README.md"]
	s.files = `git ls-files`.split("\n")

	s.add_runtime_dependency "git-version-bump", "~> 0.10"
	s.add_runtime_dependency "ffi", "~> 1.9"

	s.add_development_dependency 'bundler'
	s.add_development_dependency 'github-release'
	s.add_development_dependency 'guard-spork'
	s.add_development_dependency 'guard-rspec'
	# Needed for guard
	s.add_development_dependency 'rb-inotify', '~> 0.9'
	s.add_development_dependency 'pry-debugger'
	s.add_development_dependency 'rake'
	s.add_development_dependency 'rdoc'
	s.add_development_dependency 'rspec'
end
