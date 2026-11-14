# frozen_string_literal: true

require_relative 'test_helper'
require 'better_together/google_analytics'

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

  include ConsentSystemHelper

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
    assert_includes rendered, 'gtag(\'config\', "G-TEST123", {"anonymize_ip":true,"send_page_view":false});'
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

  include ConsentSystemHelper

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

  def test_consent_mode_sets_denied_defaults_when_ce_has_a_consent_system
    values = { 'google_analytics.measurement_id' => 'G-AAAAAAAAAA' }

    with_consent_system(true) { assert_includes render(platform(values)), "analytics_storage: 'denied'" }
    with_consent_system(false) { refute_includes render(platform(values)), 'denied' }
  end

  def test_anonymize_ip_defaults_on_and_dnt_is_opt_in
    out = render(platform('google_analytics.measurement_id' => 'G-AAAAAAAAAA'))

    assert_includes out, '"anonymize_ip":true'
    refute_includes out, 'doNotTrack'
    assert_includes render(platform('google_analytics.measurement_id' => 'G-AAAAAAAAAA',
                                    'google_analytics.respect_dnt' => true)), 'doNotTrack'
  end
end

class BetterTogetherGoogleAnalyticsConsentTest < Minitest::Test
  include ConsentSystemHelper

  ID = 'google_analytics.measurement_id'

  def platform(values)
    FakePlatform::SettingPlatform.new(values)
  end

  def test_provider_returns_analytics_only_for_a_platform_with_an_id
    tags = BetterTogether::GoogleAnalytics::HeadTags

    assert_equal :analytics, tags.consent_categories(platform(ID => 'G-AAAAAAAAAA'))
    assert_equal false, tags.consent_categories(platform({}))
    assert_equal false, tags.consent_categories(platform(ID => 'UA-1'))
  end

  def test_registered_provider_asks_for_analytics_only_when_an_id_exists
    registered = nil
    stub_registry(:register_consent_provider, ->(key, &block) { registered = [key, block] }) do
      BetterTogether::GoogleAnalytics.register_consent!
    end

    assert_equal :google_analytics, registered[0]
    assert_equal :analytics, registered[1].call(platform(ID => 'G-AAAAAAAAAA'))
    assert_equal false, registered[1].call(platform({}))
  end

  def test_consent_mode_reacts_to_the_event_and_the_stored_cookie
    js = BetterTogether::GoogleAnalytics::HeadTags.bootstrap_js('G-AAAAAAAAAA', consent_required: true,
                                                                                policy_version: 'abc123')

    assert_includes js, "gtag('consent', 'default'"
    assert_includes js, "addEventListener('better_together:consent'"
    assert_includes js, 'analytics_storage: c.analytics'
    assert_includes js, 'ad_personalization: c.marketing'
    assert_includes js, 'bt_consent='
    assert_includes js, 'var policyVersion = "abc123";'
  end

  def test_default_is_set_before_the_cookie_update_and_before_config
    js = BetterTogether::GoogleAnalytics::HeadTags.bootstrap_js('G-AAAAAAAAAA', consent_required: true)

    assert_operator js.index("gtag('consent', 'default'"), :<, js.index("gtag('consent', 'update'")
    assert_operator js.index("gtag('consent', 'update'"), :<, js.index("gtag('config'")
  end

  def test_no_consent_code_when_consent_mode_is_off
    js = BetterTogether::GoogleAnalytics::HeadTags.bootstrap_js('G-AAAAAAAAAA')

    refute_includes js, 'better_together:consent'
  end

  def test_policy_version_comes_from_the_view_when_available
    view = Struct.new(:v) { def consent_policy_version(_platform) = v }.new('pv9')

    with_consent_system(true) do
      assert_equal 'pv9', BetterTogether::GoogleAnalytics::HeadTags.policy_version(view, nil)
    end
    with_consent_system(false) do
      assert_nil BetterTogether::GoogleAnalytics::HeadTags.policy_version(view, nil)
    end
  end

  def test_cookie_list_names_the_property_cookie_after_the_measurement_id
    names = BetterTogether::GoogleAnalytics.cookie_list(platform(ID => 'G-ABCD1234')).map { |c| c[:name] }

    assert_equal %w[_ga _ga_ABCD1234], names
  end
end

class BetterTogetherGoogleAnalyticsTrackingExclusionTest < Minitest::Test
  HeadTags = BetterTogether::GoogleAnalytics::HeadTags

  class View < BetterTogetherGoogleAnalyticsHeadTagsTest::FakeViewContext
    def initialize(allowed)
      super('n')
      @allowed = allowed
    end

    def third_party_tracking_allowed? = @allowed
  end

  def render_with(view)
    ENV['GTAG_ID'] = 'G-TEST123'
    HeadTags.render(view)
  ensure
    ENV.delete('GTAG_ID')
  end

  def test_nothing_is_rendered_when_the_page_is_excluded
    assert_nil render_with(View.new(false))
  end

  def test_rendered_when_the_page_is_allowed
    assert_includes render_with(View.new(true)), 'gtag/js?id=G-TEST123'
  end

  def test_engines_without_the_helper_still_render
    assert_includes render_with(BetterTogetherGoogleAnalyticsHeadTagsTest::FakeViewContext.new('n')), 'gtag/js'
  end

  def test_page_views_check_the_meta_tag_and_strip_secrets
    js = HeadTags.bootstrap_js('G-TEST123')

    assert_includes js, 'bt-third-party-tracking'
    assert_includes js, 'turbo:before-visit'
    assert_includes js, 'turbo:load'
    assert_includes js, 'reset_password_token'
    assert_includes js, "gtag('event', 'page_view'"
  end

  def test_do_not_track_flag_is_only_set_when_requested
    assert_includes HeadTags.bootstrap_js('G-TEST123', respect_dnt: true), 'var dnt = (navigator.doNotTrack'
    assert_includes HeadTags.bootstrap_js('G-TEST123'), 'var dnt = false;'
  end
end
