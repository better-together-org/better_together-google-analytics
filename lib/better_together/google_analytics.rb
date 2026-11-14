# frozen_string_literal: true

require 'date'
require 'erb'

require 'better_together/google_analytics/version'
require 'better_together/google_analytics/head_tags'

module BetterTogether
  module GoogleAnalytics
    module_function

    def register_settings!
      return unless BetterTogether.respond_to?(:register_platform_setting)

      group = 'Google Analytics'
      BetterTogether.register_platform_setting(
        'google_analytics.measurement_id', label: 'Measurement ID', group_label: group,
                                           hint: 'G-, GT- or GTM- id. Blank turns analytics off for this platform.',
                                           pattern: HeadTags::ID_FORMAT, env_fallback: 'GTAG_ID'
      )
      {
        'anonymize_ip' => ['Anonymize IP addresses', true],
        'respect_dnt' => ['Respect Do Not Track', false],
        'enabled_on_staging' => ['Also track on staging hosts', false],
        'skip_for_stewards' => ['Do not track platform stewards', false]
      }.each do |field, (label, default)|
        BetterTogether.register_platform_setting("google_analytics.#{field}", type: :boolean, label:,
                                                                              default:, group_label: group)
      end
    end

    def register_consent!
      return unless BetterTogether.respond_to?(:register_consent_provider)

      BetterTogether.register_consent_provider(:google_analytics) { |platform| HeadTags.consent_categories(platform) }
    end

    PRIVACY_URL = 'https://policies.google.com/privacy'
    POLICY_UPDATED_ON = Date.new(2026, 11, 14)

    # The cookies Google Analytics sets, shown on the cookie policy page and in the consent
    # settings only for platforms that have a measurement id. The per-property cookie is
    # named after the measurement id, so the list is built per platform.
    def cookie_list(platform)
      id = HeadTags.measurement_id(platform)
      property = id&.start_with?('G-') ? id.delete_prefix('G-') : '<property id>'
      [
        { name: '_ga', purpose: 'Recognizes a returning browser so visits can be counted once.',
          duration: '2 years', provider: 'Google', party: :third },
        { name: "_ga_#{property}", purpose: 'Keeps the state of a visit (session) for this platform.',
          duration: '2 years', provider: 'Google', party: :third }
      ]
    end

    def register_cookie_policy!
      return unless BetterTogether.respond_to?(:register_cookie_policy_segment)

      BetterTogether.register_cookie_policy_segment(
        :google_analytics, category: :analytics, title: 'Google Analytics',
                           description: 'Counts visits and shows which pages help people, using Google Analytics. ' \
                                        'It only runs after you agree to analytics cookies.',
                           cookies: ->(platform) { cookie_list(platform) },
                           privacy_url: PRIVACY_URL, updated_on: POLICY_UPDATED_ON,
                           if: ->(platform) { !HeadTags.measurement_id(platform).nil? }
      )
    end

    def register!
      register_settings!
      register_consent!
      register_cookie_policy!
      return unless BetterTogether.respond_to?(:register_head_tag_provider)
      return unless BetterTogether.respond_to?(:register_content_security_policy_sources)

      BetterTogether.register_head_tag_provider(:google_analytics) do |view_context|
        HeadTags.render(view_context)
      end
      BetterTogether.register_content_security_policy_sources(:script_src, 'https://www.googletagmanager.com')
      BetterTogether.register_content_security_policy_sources(
        :connect_src,
        'https://www.google-analytics.com',
        'https://region1.google-analytics.com'
      )
      BetterTogether.register_content_security_policy_sources(
        :img_src,
        'https://www.google-analytics.com',
        'https://region1.google-analytics.com'
      )
    end
  end
end

BetterTogether::GoogleAnalytics.register!
