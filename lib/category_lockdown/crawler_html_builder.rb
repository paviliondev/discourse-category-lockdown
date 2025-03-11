require "request_store"

class CategoryLockdown::CrawlerHtmlBuilder
  attr_accessor :controller,
                :topic

  def self.perform(controller)
    builder = self.new(controller)
    builder.inject_html if builder.should_inject_html?
  end

  def initialize(controller)
    @controller = controller
  end

  def should_inject_html?
    return false unless controller.instance_of?(::TopicsController) &&
      SiteSetting.category_lockdown_enabled &&
      SiteSetting.category_lockdown_allow_crawlers &&
      ::RequestStore.store[:is_crawler]

    @topic = controller.instance_variable_get(:@topic_view)&.topic
    return false unless topic.present?

    CategoryLockdown.is_locked(controller.guardian, topic)
  end

  def inject_html
    inject = []

    if SiteSetting.category_lockdown_crawler_indicate_paywall
      inject.push [
                    '<script type="application/ld+json">',
                    MultiJson
                      .dump(
                        "@context" => "http://schema.org",
                        "@type" => "CreativeWork",
                        "name" => topic&.title,
                        "isAccessibleForFree" => "False",
                        "hasPart" => {
                          "@type" => "DiscussionForumPosting",
                          "isAccessibleForFree" => "False",
                          "cssSelector" => "body",
                        },
                      )
                      .gsub("</", "<\\/")
                      .html_safe,
                    "</script>",
                  ].join("")
    end

    if SiteSetting.category_lockdown_crawler_noarchive
      inject.push '<meta name="robots" content="noarchive">'
    end

    inject.join("\n")
  end
end