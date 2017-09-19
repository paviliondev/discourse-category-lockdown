import { withPluginApi } from 'discourse/lib/plugin-api';
import { default as DiscourseURL } from 'discourse/lib/url';

function initializeLockdown(api) {
  api.modifyClass('model:post-stream', {
    errorLoading(result){
      const status = result.jqXHR.status;
      if(status === 402){
        return DiscourseURL.handleURL(this.siteSettings.category_lockdown_redirect_url, {replaceURL: true});
      }
      return this._super();
    }
  });
}

export default {
  name: "apply-lockdown",

  initialize() {
    withPluginApi('0.1', initializeLockdown);
  }
};
