Spine = require('spine')

class Point extends Spine.Model
  @configure 'Point', 'team', 'sprint', 'value', 'day'

  @extend Spine.Model.Local
  @belongsTo 'chart', 'chart'
  
  @validate: (atts) ->
    return true if parseInt(atts.value) < 0


  
module.exports = Point
