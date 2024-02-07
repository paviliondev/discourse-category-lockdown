import Group from "discourse/models/group";
import { action } from "@ember/object";

export default {
  setupComponent(args, component) {
    component.set("groupFinder", (term) => {
      return Group.findAll({ term: term, ignore_automatic: false });
    });
  },
  @action
  onChangeSetting(value) {
    this.set(
      "category.custom_fields.lockdown_enabled",
      value ? "true" : "false"
    );
  },
};
