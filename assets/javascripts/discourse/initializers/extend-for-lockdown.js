import { withPluginApi } from "discourse/lib/plugin-api";
import { default as DiscourseURL } from "discourse/lib/url";
import TopicStatus from "discourse/raw-views/topic-status";
import discourseComputed from "discourse-common/utils/decorators";
import I18n from "I18n";

const PLUGIN_ID = "discourse-category-lockdown";

function initializeLockdown(api) {
  // Intercept any HTTP 402 (Payment Required) responses for topics
  // And redirect the client accordingly
  api.modifyClass("model:post-stream", {
    pluginId: PLUGIN_ID,
    errorLoading(result) {
      const status = result.jqXHR.status;
      let response = result.jqXHR.responseJSON;
      if (status === 402) {
        let redirectURL =
          response.redirect_url ||
          this.siteSettings.category_lockdown_redirect_url;

        const external = redirectURL.startsWith("http");
        if (external) {
          // Use location.replace so that the user can go back in one click
          document.location.replace(redirectURL);
        } else {
          // Handle the redirect inside ember
          return DiscourseURL.handleURL(redirectURL, { replaceURL: true });
        }
      }
      return this._super();
    },
  });

  api.modifyClass("component:topic-list-item", {
    pluginId: PLUGIN_ID,
    @discourseComputed
    unboundClassNames() {
      let classNames = this._super(...arguments) || "";
      if (this.get("topic.is_locked_down")) {
        classNames += " locked-down";
      }

      return classNames;
    },
  });

  // Add an icon next to locked-down topics
  TopicStatus.reopen({
    @discourseComputed()
    statuses() {
      const results = this._super();
      if (this.topic.is_locked_down) {
        results.push({
          openTag: "span",
          closeTag: "span",
          title: I18n.t("lockdown.topic_is_locked_down"),
          icon: this.siteSettings.category_lockdown_list_icon,
        });
      }
      return results;
    },
  });

  // Warning: "route:docs-index" may not be found if the 'discourse-docs' plugin is not installed. This is expected and harmless.
  api.modifyClass("route:docs-index", {
    pluginId: PLUGIN_ID,
    model(params, transition) {
      return this._super(params).catch((error) => {
        let response = error.jqXHR.responseJSON;
        const status = error.jqXHR.status;
        if (status === 402) {
          // abort the transition to prevent momentary error
          // from being displayed
          transition.abort();
          let redirectURL =
            response.redirect_url ||
            this.siteSettings.category_lockdown_redirect_url;

          const external = redirectURL.startsWith("http");
          if (external) {
            document.location.href = redirectURL;
          } else {
            // Handle the redirect inside ember
            return DiscourseURL.handleURL(redirectURL, { replaceURL: true });
          }
        }
      });
    },
  });
}

export default {
  name: "apply-lockdown",

  initialize() {
    withPluginApi("0.1", initializeLockdown);
  },
};
