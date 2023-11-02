# frozen_string_literal: true
# name: discourse-category-lockdown
# about: Set all topics in a category to redirect, unless part of a specified group
# version: 0.1
# authors: David Taylor, Angus McLeod, Robert Barrow, Juan Marcos Gutierrez Ramos
# url: https://github.com/paviliondev/discourse-category-lockdown

enabled_site_setting :category_lockdown_enabled

register_asset 'stylesheets/lockdown.scss'
require 'request_store'

after_initialize do
  register_category_custom_field_type('redirect_url', :string)

  Site.preloaded_category_custom_fields << 'redirect_url'
  if defined?(register_category_list_preloaded_category_custom_fields)
    register_category_list_preloaded_category_custom_fields('redirect_url')
  end

  add_to_serializer(:basic_category, :redirect_url, false) do
    object.custom_fields['redirect_url']
  end

  def before_head_close_meta(controller)
    return "" if !controller.instance_of? TopicsController
    return "" unless SiteSetting.category_lockdown_enabled
    return "" unless SiteSetting.category_lockdown_allow_crawlers
    return "" unless ::RequestStore.store[:is_crawler]

    topic_view = controller.instance_variable_get(:@topic_view)
    topic = topic_view&.topic
    return "" if !topic

    if CategoryLockdown.is_locked(controller.guardian, topic)
      inject = []
      if SiteSetting.category_lockdown_crawler_indicate_paywall
        inject.push [
          '<script type="application/ld+json">', 
          MultiJson.dump(
            '@context' => 'http://schema.org',
            '@type' => 'CreativeWork',
            'name' => topic&.title,
            'isAccessibleForFree' => 'False',
            'hasPart' => {
              '@type' => 'DiscussionForumPosting',
              'isAccessibleForFree' => 'False',
              'cssSelector' => 'body'
            },
          ).gsub("</", "<\\/").html_safe, 
          '</script>',
        ].join("")  
      end
      if SiteSetting.category_lockdown_crawler_noarchive
        inject.push '<meta name="robots" content="noarchive">'
      end

      inject.join("\n")
    end
  end

  register_html_builder('server:before-head-close-crawler') do |controller|
    before_head_close_meta(controller)
  end

  module ::TopicControllerLockdownExtension
    def show
      ::RequestStore.store[:is_crawler] = use_crawler_layout?
      super
    end
  end

  ::TopicsController.prepend ::TopicControllerLockdownExtension

  module ::CategoryLockdown
    def self.is_locked(guardian, topic)
      return false if guardian.is_admin?

      if SiteSetting.allow_authors_in_locked_categories &&
           guardian&.user&.id == topic&.user_id
        return false
      end

      locked_down = topic.category&.custom_fields&.[]("lockdown_enabled") == "true"
      return false if !locked_down

      allowed_groups = topic.category&.custom_fields&.[]("lockdown_allowed_groups")
      allowed_groups = '' if allowed_groups.nil?
      allowed_groups = allowed_groups.split(',')

      in_allowed_groups = guardian&.user&.groups&.where(name: allowed_groups)&.exists?

      !in_allowed_groups
    end

    class NoAccessLocked < StandardError; end
  end

  # Restrict topic views, including RSS/Print/Search-engine
  require_dependency 'topic_view'

  module TopicViewLockdownExtension
    def check_and_raise_exceptions(skip_staff_action)
      super
      return if ::RequestStore.store[:is_crawler] && SiteSetting.category_lockdown_allow_crawlers
      raise ::CategoryLockdown::NoAccessLocked.new if SiteSetting.category_lockdown_enabled && CategoryLockdown.is_locked(@guardian, @topic)
    end
  end

  ::TopicView.prepend TopicViewLockdownExtension

  TopicList.preloaded_custom_fields << "lockdown_enabled"
  TopicList.preloaded_custom_fields << "lockdown_allowed_groups"

  require_dependency 'application_controller'
  class ::ApplicationController
    rescue_from ::CategoryLockdown::NoAccessLocked do
      opts = {
        include_ember: true
      }
      topic_id = params["topic_id"] || params["id"]
      topic_id ||= params["topic"] # if coming from discourse-docs plugin
      topic = Topic.find(topic_id.to_i) if topic_id
      response = {
        error: "Payment Required",
      }
      response[:redirect_url] = topic.category.custom_fields["redirect_url"] if topic
      response[:redirect_url] ||= SiteSetting.category_lockdown_redirect_url
      if request.format.json?
        render_json_dump(response, status: 402)
      else
        redirect_to path(response[:redirect_url]), status: :moved_permanently
      end

    end
  end

  # Restrict access to posts (e.g. /raw/12/2)
  # Also covers notifications, so people cannot 'watch' the topic
  require_dependency 'guardian'
  module ::PostGuardian
    alias_method :old_can_see_post?, :can_see_post?

    def can_see_post?(post)
      return old_can_see_post?(post) unless SiteSetting.category_lockdown_enabled

      return false if !old_can_see_post?(post)
      return false if ::CategoryLockdown.is_locked(self, post.topic)

      true
    end
  end

  # Add a boolean to the topic list serializer
  # So that we can show an icon next to each topic
  require_dependency 'topic_list_item_serializer'
  class ::TopicListItemSerializer
    attributes :is_locked_down

    def is_locked_down
      ::CategoryLockdown.is_locked(scope, object)
    end

    def include_is_locked_down?
      SiteSetting.category_lockdown_enabled
    end

  end

end
