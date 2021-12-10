import { withPluginApi } from "discourse/lib/plugin-api";
import { default as DiscourseURL } from "discourse/lib/url";
import TopicStatus from "discourse/raw-views/topic-status";
import discourseComputed from "discourse-common/utils/decorators";
import { helperContext } from "discourse-common/lib/helpers";

function initializeLockdown(api) {
  // Intercept any HTTP 402 (Payment Required) responses for topics
  // And redirect the client accordingly
  api.modifyClass("model:post-stream", {
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

  api.modifyClassStatic("model:docs", {
    list(params) {
      return this._super(params).catch(error => {
        let response = error.jqXHR.responseJSON;
        const status = error.jqXHR.status;
        if (status === 402) {
          // using helperContext() instead of `this` as as its a static context
          let redirectURL =
            response.redirect_url ||
            helperContext().siteSettings.category_lockdown_redirect_url;

          const external = redirectURL.startsWith("http");
          if (external) {
            // Use location.replace so that the user can go back in one click
            document.location.replace(redirectURL);
          } else {
            // Handle the redirect inside ember
            return DiscourseURL.handleURL(redirectURL, { replaceURL: true });
          }
        }
      });
    }
  });
}

export default {
  name: "apply-lockdown",

  initialize() {
    withPluginApi("0.1", initializeLockdown);
  },
};
