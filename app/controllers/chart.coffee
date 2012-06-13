Spine = require('spine')
Chart = require('models/chart')
Point = require('models/point')
$ = Spine.$

class Main extends Spine.Controller
  events:
    'click .add-point': 'addPoint'
    "change #project-select": "setTeam"

  elements:
    "#project-select": "projectSelect"

  constructor: ->
    super
    Chart.bind 'create update refresh', @plot
    @getConfig()
    if @config.project?
      @chart = Chart.findByAttribute
        team: @config.team
        sprint: @config.sprint
    else
      @chart = Chart.create()

  addPoint: ->
    e.preventDefault()

  plot: =>
    @render()

  setTeam: (e) ->
    console.log @projectSelect.val()

  getConfig: ->
    @config =
      team: $.cookie 'team' ? null
      sprint: $.cookie 'sprint' ? null

  setConfig: (options) ->
    $.cookie 'team', options.team
    $.cookie 'sprint', options.sprint
    @getConfig()

  render: ->
    return false unless @chart
    @html require('views/chart')(@chart)
    
module.exports = Main
