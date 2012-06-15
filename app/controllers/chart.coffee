Spine = require('spine')
Chart = require('models/chart')
Sprint = require('models/sprint')
Point = require('models/point')
$ = Spine.$

class Main extends Spine.Controller
  events:
    'click .btn-preview': 'preview'
    'click .btn-commit': 'commit'
    'click .new-sprint-btn': 'newSprint'
    'click .create-sprint-btn': 'createSprint'
    'click .cancel-sprint-btn': 'setSprint'
    "change .team-select": "setTeam"
    "keydown #point-input": "changingPoint"

  elements:
    ".team-select": "teamSelect"
    "#day-select": "daySelect"
    "#point-input": "pointInput"
    ".chart": "chartGraph"
    "#start-date-input": "startDateInput"

  sprint: null
  sprints: []
  chart: null
  points: []

  constructor: ->
    super
    Chart.bind 'create', @addChart
    Chart.bind 'update refresh', @plot
    Sprint.bind 'fetch', @setSprint
    Sprint.bind 'create', @setSprint
    Point.bind 'create', @plot

    @getConfig()
    return @navigate('/team') unless @config.team? and @teams.indexOf(@config.team) != -1

    @routes
      '/on/team/:team': (param) =>
        return @navigate '/team' unless param.team? or param.team is ""
        @setConfig
          team: decodeURIComponent(param.team)
          sprint: -1
        @setSprint()
      '/on/team/:team/sprint/:sprint': (param) =>
        @setConfig
          team: decodeURIComponent(param.team)
          sprint: decodeURIComponent(param.sprint)
        result = Sprint.select (sprint) =>
          return true if sprint.team = @config.team and sprint.number = @config.sprint
        sprint = result.pop() if result.length > 0
        @render()
      '/on/team/:team/create/sprint': (param) =>
        @setConfig team: decodeURIComponent(param.team)
        @sprint = null
        @render()
      '/team': =>
        @setConfig
          team: null
          sprint: null
        @render('select_team')
      '/': =>
        @navigate '/on/team', encodeURIComponent(@config.team)

    Sprint.fetch()
      

  changingPoint: (e) ->
    if e.keyCode is 13
      e.stopPropagation()
      @commit()

  setTeam: (e) ->
    @setConfig
      team: @teamSelect.val()
      sprint: -1
    @setSprint()

  newSprint: =>
    @navigate '/on/team', encodeURIComponent(@config.team), 'create/sprint'

  createSprint: =>
    if @startDateInput.val() is ""
      startDate = Date.today()
    else
      startDate = Date.parse(@startDateInput.val())
    endDate = startDate.add(@config.length)

    Sprint.create
      team: @config.team
      number: parseInt(@config.sprint) + 1
      started_at: startDate.asString()
      end_at: endDate.asString()

  addSprint: (sprint) =>
    @sprint = sprint
    console.log Date.compare Date.today(), Date.parse(@sprint.started_at)
    chart = Chart.findByAttribute
      team: @sprint.team
      sprint: @sprint.number

    console.log chart


  setSprint: (sprint) =>
    unless sprint instanceof Sprint
    unless sprint
      sprint = Sprint.findByAttribute "team", @config.team
      if sprint
        return @navigate '/on/team', encodeURIComponent(sprint.team), 'sprint', sprint.number
      else
        return @navigate '/on/team', encodeURIComponent(@config.team), 'create/sprint'
    @sprint = sprint
    @navigate '/on/team', @config.team, 'sprint', sprint.number

  getChart: ->
    return unless @config.sprint?
    return @chart = chart if chart instanceof Chart
    @chart = new Chart
      team: @config.team
      sprint: @config.sprint
    @chart

  addChart: ->
    @getPoint()
    @render()

  getPoints: ->
    Point.findAllbyAttribute
      team: @config.team
      sprint: @config.sprint

  setConfig: (options) ->
    for name, value of options
      $.cookie name, value
    @config = @getConfig()

  getConfig: ->
    @config =
      team: decodeURIComponent($.cookie('team')) ? null
      sprint: $.cookie('sprint') ? 0
      length: 15
    @config

  preview: (e) ->
    e.preventDefault()
    point = new Point
      value: @pointInput.val()
    @plot()

  commit: (e) ->
    e.preventDefault()
    #@chart.save()
    @plot()

  render: (view = 'chart') ->
    view = 'select_team' unless @config.team? and @teams.indexOf(@config.team) != -1
    @replace require('views/' + view)(
      teams: @teams
      config: @config
      sprint: @sprint
      sprints: @sprints
      chart: @chart
    )
    $(".chzn-select").chosen()
    @daySelect.datePicker()
    @startDateInput.datePicker()
    @startDateInput.bind 'dpClosed', (e, dates) =>
      d = dates[0].asString()
      $("#start-date").html(d)
      @startDateInput.val(d)
    @

  plot: ->
    
    
module.exports = Main
