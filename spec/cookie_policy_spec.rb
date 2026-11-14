# frozen_string_literal: true

require_relative 'spec_helper'

RSpec.describe 'Google Analytics cookie policy and consent registration' do
  include_context 'with an isolated cookie policy registry' if CE_CONSENT_API

  let(:id_key) { 'google_analytics.measurement_id' }
  let(:with_id) { SpecPlatform.new(id_key => 'G-ABCD1234') }
  let(:without_id) { SpecPlatform.new }

  before do
    next unless CE_CONSENT_API

    BetterTogether::GoogleAnalytics.register_settings!
    BetterTogether::GoogleAnalytics.register_consent!
    BetterTogether::GoogleAnalytics.register_cookie_policy!
  end

  describe 'segment for a platform with a measurement id' do
    let(:platform) { with_id }

    it_behaves_like 'a cookie policy segment', :google_analytics, category: :analytics if CE_CONSENT_API

    it 'describes _ga and the per-property cookie for two years, third party, with the Google privacy link',
       :aggregate_failures do
      segment = BetterTogether::CookiePolicy.resolved_segments(platform).find { |s| s.key == :google_analytics }

      expect(segment.cookies.map(&:name)).to eq(%w[_ga _ga_ABCD1234])
      expect(segment.cookies.map(&:duration).uniq).to eq(['2 years'])
      expect(segment.cookies.map(&:provider).uniq).to eq(['Google'])
      expect(segment.cookies).to all(be_third_party)
      expect(segment.privacy_url).to eq('https://policies.google.com/privacy')
    end
  end

  describe 'a platform without a measurement id' do
    it 'hides the segment and asks for no consent', :aggregate_failures do
      keys = BetterTogether::CookiePolicy.resolved_segments(without_id).map(&:key)

      expect(keys).not_to include(:google_analytics)
      expect(BetterTogether::Consent.provider_categories(without_id)).to be_empty
      expect(BetterTogether::Consent.categories_in_use(without_id)).to be_empty
    end
  end

  describe 'two platforms' do
    it 'shows the segment and asks for analytics only on the one with an id', :aggregate_failures do
      other = SpecPlatform.new(id_key => 'G-ZZZZ9999')

      expect(BetterTogether::Consent.provider_categories(with_id)).to eq(%w[analytics])
      expect(BetterTogether::Consent.provider_categories(without_id)).to eq([])
      names = BetterTogether::CookiePolicy.resolved_segments(other).find { |s| s.key == :google_analytics }
                                          .cookies.map(&:name)
      expect(names).to eq(%w[_ga _ga_ZZZZ9999])
    end

    it 'changes the consent policy version between them' do
      expect(BetterTogether::Consent.policy_version(with_id)).not_to eq(BetterTogether::Consent.policy_version(without_id))
    end
  end

  describe 'environment fallback' do
    around do |example|
      original = ENV.fetch('GTAG_ID', nil)
      ENV['GTAG_ID'] = 'G-ENVID1234'
      example.run
    ensure
      original.nil? ? ENV.delete('GTAG_ID') : ENV['GTAG_ID'] = original
    end

    it 'applies to the host platform only', :aggregate_failures do
      host = SpecPlatform.host
      guest = SpecPlatform.new

      expect(BetterTogether::Consent.provider_categories(host)).to eq(%w[analytics])
      expect(BetterTogether::Consent.provider_categories(guest)).to be_empty
      expect(BetterTogether::CookiePolicy.resolved_segments(host).map(&:key)).to include(:google_analytics)
      expect(BetterTogether::CookiePolicy.resolved_segments(guest).map(&:key)).not_to include(:google_analytics)
    end

    it 'lets the platform value win over the environment' do
      host = SpecPlatform.host(id_key => 'G-OWN00001')
      names = BetterTogether::CookiePolicy.resolved_segments(host).find { |s| s.key == :google_analytics }.cookies.map(&:name)

      expect(names).to eq(%w[_ga _ga_OWN00001])
    end
  end
end
