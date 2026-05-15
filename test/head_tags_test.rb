# frozen_string_literal: true

require 'minitest/autorun'
require 'better_together/google_analytics/head_tags'

class BetterTogetherGoogleAnalyticsHeadTagsTest < Minitest::Test
  FakeViewContext = Struct.new(:nonce) do
    def content_security_policy_nonce
      nonce
    end

    def javascript_include_tag(src, async:, nonce:)
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
    assert_includes rendered, 'gtag(\'config\', "G-TEST123");'
    assert_includes rendered, "window.addEventListener('better_together:share'"
  end
end
