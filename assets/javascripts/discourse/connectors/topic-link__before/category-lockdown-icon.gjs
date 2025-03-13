import Component from "@glimmer/component";
import { service } from "@ember/service";
import i18n from "discourse-common/helpers/i18n";
import icon from "discourse-common/helpers/d-icon";

 export default class CategoryLockdownIcon extends Component {
   @service siteSettings;
 
  <template>
    {{~#if this.siteSettings.category_lockdown_enabled~}}
      {{~#if @outletArgs.topic.is_locked_down~}}
        <span title={{i18n "lockdown.topic_is_locked_down"}}>
          {{icon
            this.siteSettings.category_lockdown_list_icon
          }}
        </span>
      {{~/if~}}
    {{~/if~}}
   </template>
 }