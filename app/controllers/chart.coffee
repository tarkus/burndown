Spine = require('spine')
Chart = require('models/chart')
Point = require('models/point')
$ = Spine.$

class Main extends Spine.Controller
  events:
    'click .btn-preview': 'preview'
    'click .btn-commit': 'commit'
    "change .team-select": "setTeam"
    "keydown #point-input": "changingPoint"

  elements:
    ".team-select": "teamSelect"
    "#day-select": "daySelect"
    ".date-picker": "datePicker"
    "#point-input": "pointInput"
    ".chart": "chartGraph"

  constructor: ->
    super
    Chart.bind 'create update refresh', @plot
    Point.bind 'create', @plot
    @getConfig()
    if @config.project?
      @chart = Chart.findByAttribute
        team: @config.team
        sprint: @config.sprint
    else
      @chart = new Chart
      
    @routes
      '/on/team/:team': (param) =>
        @setConfig team: decodeURIComponent(param.team)

  changingPoint: (e) ->
    if e.keyCode is 13
      e.stopPropagation()
      @commit()

  setTeam: (e) ->
    @setConfig team: @teamSelect.val()

  getConfig: ->
    @config =
      team: $.cookie 'team' ? null
      sprint: $.cookie 'sprint' ? null
      length: 15

  setConfig: (options) ->
    for name, value of options
      $.cookie name, value
    @getConfig()
    @render()

  commit: (e) ->
    e.preventDefault()
    #@chart.save()
    @plot()

  preview: (e) ->
    e.preventDefault()
    point = new Point
      value: @pointInput.val()
    @plot()

  render: (view = 'chart') ->
    return false unless @chart?
    view = 'config' unless @config.team?
    @replace require('views/' + view)(chart: @chart, config: @config, teams: @teams)
    $(".chzn-select").chosen()
    @datePicker.datePicker()
    @datePicker.dpSetStartDate(new Date().addDays(-5).asString())
    @

  plot: ->
    
    
module.exports = Main
