require 'lib/setup'

Spine = require 'spine'
Chart = require 'controllers/chart'

class ChartApp extends Spine.Controller
  constructor: ->
    super
    @chart = new Chart
      teams: ['G Unit', 'K Team', 'P Team']
    @render()
    @append @chart.render()
    Spine.Route.setup()

  render: ->
    @html require('views/layout')
    @

module.exports = ChartApp
    
