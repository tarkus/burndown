Spine = require('spine')

class Sprint extends Spine.Model
  @configure 'Sprint', "team", "number", "points", "started_at", "end_at"
  
  @extend Spine.Model.Local

module.exports = Sprint
