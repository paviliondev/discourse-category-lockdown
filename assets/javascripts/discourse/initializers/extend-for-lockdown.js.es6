import { withPluginApi } from 'discourse/lib/plugin-api';
import { default as DiscourseURL } from 'discourse/lib/url';
import TopicStatus from 'discourse/raw-views/topic-status';

function initializeLockdown(api) {
  // Intercept any HTTP 402 (Payment Required) responses for topics
  // And redirect the client accordingly
  api.modifyClass('model:post-stream', {
    errorLoading(result){
      const status = result.jqXHR.status;
      if(status === 402){
        const redirectURL = this.siteSettings.category_lockdown_redirect_url;
        const external = redirectURL.startsWith("http");
        if(external){
          // Use location.replace so that the user can go back in one click
          document.location.replace(redirectURL);
        }else{
          // Handle the redirect inside ember
          return DiscourseURL.handleURL(redirectURL, {replaceURL: true});
        }
      }
      return this._super();
    }
  });

  // Add an icon next to locked-down topics
  TopicStatus.reopen({
    statuses: function(){
      const results = this._super();
      if (this.topic.is_locked_down) {
        results.push({
          openTag: 'span',
          closeTag: 'span',
          title: I18n.t('lockdown.topic_is_locked_down'),
          icon: this.siteSettings.category_lockdown_list_icon
        });
      }
      return results;
    }.property()
  });
}

export default {
  name: "apply-lockdown",

  initialize() {
    withPluginApi('0.1', initializeLockdown);
  }
};
