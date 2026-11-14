# frozen_string_literal: true

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
        'skip_for_stewards' => ['Do not track platform stewards', false],
        'consent_required' => ['Wait for visitor consent (consent mode v2)', false]
      }.each do |field, (label, default)|
        BetterTogether.register_platform_setting("google_analytics.#{field}", type: :boolean, label:,
                                                                              default:, group_label: group)
      end
    end

    def register!
      register_settings!
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
