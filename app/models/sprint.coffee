Spine = require('spine')

class Sprint extends Spine.Model
  @configure 'Sprint', "team", "number", "point", "started_at", "end_at"
  
  @extend Spine.Model.Local

module.exports = Sprint
