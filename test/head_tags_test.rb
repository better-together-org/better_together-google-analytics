# frozen_string_literal: true

require_relative 'test_helper'
require 'better_together/google_analytics/head_tags'

class BetterTogetherGoogleAnalyticsHeadTagsTest < Minitest::Test
  FakeViewContext = Struct.new(:nonce) do
    def content_security_policy_nonce
      nonce
    end

    def javascript_include_tag(src, nonce:, **)
      %(<script async="async" nonce="#{nonce}" src="#{src}"></script>)
    end

    def javascript_tag(content, nonce:)
      %(<script nonce="#{nonce}">#{content.strip}</script>)
    end

    def safe_join(parts, separator)
      parts.join(separator)
    end
  end

  def with_gtag_id(value)
    original = ENV.fetch('GTAG_ID', nil)
    value.nil? ? ENV.delete('GTAG_ID') : ENV['GTAG_ID'] = value
    yield
  ensure
    original.nil? ? ENV.delete('GTAG_ID') : ENV['GTAG_ID'] = original
  end

  def test_render_returns_nil_when_gtag_id_is_blank
    with_gtag_id(nil) do
      assert_nil BetterTogether::GoogleAnalytics::HeadTags.render(FakeViewContext.new('nonce-123'))
    end
  end

  def test_render_builds_nonce_safe_google_tag_markup
    rendered = with_gtag_id('G-TEST123') do
      BetterTogether::GoogleAnalytics::HeadTags.render(FakeViewContext.new('nonce-123'))
    end

    assert_includes rendered, 'https://www.googletagmanager.com/gtag/js?id=G-TEST123'
    assert_includes rendered, 'nonce="nonce-123"'
    assert_includes rendered, 'window.GA_ID = "G-TEST123";'
    assert_includes rendered, 'gtag(\'config\', "G-TEST123", {"anonymize_ip":true});'
    assert_includes rendered, "window.addEventListener('better_together:share'"
  end
end

class BetterTogetherGoogleAnalyticsPerPlatformTest < Minitest::Test
  Request = Struct.new(:host)

  # View double exposing the helpers HeadTags consults on a CE request.
  class PlatformView < BetterTogetherGoogleAnalyticsHeadTagsTest::FakeViewContext
    attr_reader :host_platform, :request, :current_user

    def initialize(platform, host: 'example.org', user: nil)
      super('n')
      @host_platform = platform
      @request = Request.new(host)
      @current_user = user
    end
  end

  Steward = Struct.new(:allowed) do
    def permitted_to?(_identifier, _platform) = allowed
  end

  def platform(values = {})
    FakePlatform::SettingPlatform.new(values)
  end

  def render(platform, **)
    BetterTogether::GoogleAnalytics::HeadTags.render(PlatformView.new(platform, **))
  end

  def test_two_platforms_get_their_own_ids
    first = render(platform('google_analytics.measurement_id' => 'G-AAAAAAAAAA'))
    second = render(platform('google_analytics.measurement_id' => 'G-BBBBBBBBBB'))

    assert_includes first, 'G-AAAAAAAAAA'
    refute_includes first, 'G-BBBBBBBBBB'
    assert_includes second, 'G-BBBBBBBBBB'
  end

  def test_platform_without_an_id_renders_nothing
    assert_nil render(platform)
  end

  def test_invalid_id_renders_nothing
    assert_nil render(platform('google_analytics.measurement_id' => 'UA-123'))
  end

  def test_staging_host_is_skipped_unless_enabled
    values = { 'google_analytics.measurement_id' => 'G-AAAAAAAAAA' }

    assert_nil render(platform(values), host: 'staging.example.org')
    assert render(platform(values.merge('google_analytics.enabled_on_staging' => true)), host: 'staging.example.org')
  end

  def test_stewards_are_skipped_when_configured
    values = { 'google_analytics.measurement_id' => 'G-AAAAAAAAAA', 'google_analytics.skip_for_stewards' => true }

    assert_nil render(platform(values), user: Steward.new(true))
    assert render(platform(values), user: Steward.new(false))
  end

  def test_consent_required_sets_denied_defaults
    values = { 'google_analytics.measurement_id' => 'G-AAAAAAAAAA', 'google_analytics.consent_required' => true }

    assert_includes render(platform(values)), "analytics_storage: 'denied'"
    refute_includes render(platform('google_analytics.measurement_id' => 'G-AAAAAAAAAA')), 'denied'
  end

  def test_anonymize_ip_defaults_on_and_dnt_is_opt_in
    out = render(platform('google_analytics.measurement_id' => 'G-AAAAAAAAAA'))

    assert_includes out, '"anonymize_ip":true'
    refute_includes out, 'doNotTrack'
    assert_includes render(platform('google_analytics.measurement_id' => 'G-AAAAAAAAAA',
                                    'google_analytics.respect_dnt' => true)), 'doNotTrack'
  end
end
