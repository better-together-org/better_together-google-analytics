# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
require 'minitest/autorun'
require_relative 'support/fake_platform'

# Toggles whether the CE consent system looks present, without loading CE.
module ConsentSystemHelper
  def with_consent_system(present)
    singleton = BetterTogether.singleton_class
    had = BetterTogether.respond_to?(:register_consent_provider)
    singleton.send(:define_method, :register_consent_provider) { |*| nil } if present && !had
    singleton.send(:remove_method, :register_consent_provider) if !present && had
    yield
  ensure
    singleton.send(:remove_method, :register_consent_provider) if singleton.method_defined?(:register_consent_provider) && !had
  end

  def stub_registry(name, callable)
    singleton = BetterTogether.singleton_class
    singleton.send(:define_method, name) { |*args, &block| callable.call(*args, &block) }
    yield
  ensure
    singleton.send(:remove_method, name)
  end
end
