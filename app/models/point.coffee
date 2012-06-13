Spine = require('spine')

class Point extends Spine.Model
  @configure 'Point', 'team', 'sprint', 'value', 'day'

  @extend Spine.Model.Local
  @belongsTo 'chart', 'chart'
  
module.exports = Point
