import Group from 'discourse/models/group';

export default {
  setupComponent(args, component) {
    component.set('groupFinder', (term) => {
      return Group.findAll({ term: term, ignore_automatic: false });
    });
  }

};
