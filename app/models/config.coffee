Spine = require('spine')

class Config extends Spine.Model
  @configure 'Config', 'team', 'sprint'

  @extend Spine.Model.Local

  @get: (cb) ->
    @fetch () =>
      console.log 'good?'
      if @all().length is 0
        config = new Config
      else
        config = @all().pop()
      cb?(config)
  
module.exports = Config
window.Config = Config
