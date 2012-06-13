Spine = require('spine')

class Chart extends Spine.Model
  @configure 'Chart', 'team', 'sprint', 'updated_at'

  @extend Spine.Model.Local
  @hasMany 'points', 'point'
  
module.exports = Chart
