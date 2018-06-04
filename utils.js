var _ = require("underscore");

var utils = {
  arrify: function(data) {
    return (data instanceof Array) ? data : [data];
  },

  existy: function(data) {
    return !(_.isNaN(data) || _.isNull(data) || _.isUndefined(data));
  },

  intersects: function(comparator, array1, array2) {
    return utils.existy(array1.find(function(element1) {
      return utils.existy(array2.find(function(element2) {
        return comparator(element1, element2);
      }));
    }));
  }
};

module.exports = utils;
