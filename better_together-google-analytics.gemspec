# frozen_string_literal: true

$LOAD_PATH.push File.expand_path('lib', __dir__)

require 'better_together/google_analytics/version'

Gem::Specification.new do |spec|
  spec.name          = 'better_together-google-analytics'
  spec.version       = BetterTogether::GoogleAnalytics::VERSION
  spec.authors       = ['Robert JJ Smith']
  spec.email         = ['rob@bettertogethersolutions.com']
  spec.summary       = 'Google Analytics provider gem for Better Together.'
  spec.description   = 'Registers Google Analytics head tags and CSP sources for Better Together host apps without duplicating host-app view partials.'
  spec.homepage      = 'https://github.com/better-together-org'
  spec.license       = 'LGPL-3.0-or-later'
  spec.required_ruby_version = '>= 3.2'

  spec.files = Dir['lib/**/*', 'README.md', 'LICENSE*']
  spec.require_paths = ['lib']

  spec.add_dependency 'better_together', '>= 0.11.0'
end
