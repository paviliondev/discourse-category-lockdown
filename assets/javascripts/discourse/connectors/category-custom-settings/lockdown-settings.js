import Component from '@glimmer/component';
import Group from "discourse/models/group";
import { action, computed } from "@ember/object";
import { inject as service } from "@ember/service";
import { tracked } from '@glimmer/tracking';

export default class LockdownSettings extends Component {
  @service site;
  @tracked selectedGroups = null;

  constructor() {
    super(...arguments);
    this.selectedGroups = (this.args.outletArgs.category.custom_fields.lockdown_allowed_groups || "").split(",").filter(Boolean);
  }

  @computed("site.groups.[]")
  get availableGroups() {
    return (this.site.groups || [])
      .map((g) => {
        // prevents group "everyone" to be listed
        return g.id === 0 ? null : g.name;
      })
      .filter(Boolean);
  }


  @action
  onChangeGroups(values) {
    this.selectedGroups = values;
    this.args.outletArgs.category.custom_fields.lockdown_allowed_groups = values.join(",");
  }
};
