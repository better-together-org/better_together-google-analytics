# frozen_string_literal: true

# Minimal stand-ins for the CE objects the gem reads, so the unit tests run
# without a Rails dummy app. Two platforms with different settings are the
# core fixture for the per-platform specs added in I4.
module FakePlatform
  Platform = Struct.new(:name, :host, :settings, keyword_init: true) do
    def setting(key)
      settings[key]
    end
  end

  def self.nlmushrooms
    Platform.new(name: 'Foray NL', host: false, settings: { 'google_analytics.measurement_id' => 'G-AAAAAAAAAA' })
  end

  def self.other
    Platform.new(name: 'Other', host: false, settings: {})
  end

  def self.host
    Platform.new(name: 'Host', host: true, settings: {})
  end
end

# Platform stand-in answering integration_setting like CE's registry-backed method.
module FakePlatform
  class SettingPlatform
    def initialize(values = {}) = @values = values

    def integration_setting(key) = @values[key]
  end
end
