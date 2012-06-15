require 'lib/setup'

Spine = require 'spine'
Chart = require 'controllers/chart'

class ChartApp extends Spine.Controller
  constructor: ->
    super
    @chart = new Chart
      teams: ['G Unit', 'K Team', 'P Team']
    @append @chart.render()

    Spine.Route.setup()

module.exports = ChartApp
    
