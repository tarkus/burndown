require 'lib/setup'

Spine = require 'spine'
Chart = require 'controllers/chart'

class ChartApp extends Spine.Controller
  constructor: ->
    super
    @chart = new Chart
    @render()
    @append @chart.render()

  render: ->
    @html require('views/layout')
    @



module.exports = ChartApp
    
