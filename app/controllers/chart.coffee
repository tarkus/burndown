Spine = require('spine')
Chart = require('models/chart')
Sprint = require('models/sprint')
Point = require('models/point')
$ = Spine.$

class Main extends Spine.Controller
  events:
    "click .create-sprint-btn": "createSprint"
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
    Sprint.bind 'create', @setSprint
    Point.bind 'create', @plot

    @getConfig()

    @routes
      '/on/team/:team': (param) =>
        team = decodeURIComponent(param.team)
        return @navigate '/team' unless @teams.indexOf(team) != -1
        @setConfig team: team
        @setSprint()
      '/on/team/:team/sprint/:sprint': (param) =>
        team = decodeURIComponent(param.team)
        return @navigate '/team' unless @teams.indexOf(team) != -1
        @setConfig team: team, sprint: param.sprint
        @setSprint()
        @render()
      '/on/team/:team/create/sprint': (param) =>
        team = decodeURIComponent(param.team)
        return @navigate '/team' unless @teams.indexOf(team) != -1
        @setConfig team: team
        @sprint = null
        @render()
      '/team': =>
        @setConfig
          team: null
          sprint: null
        @render()
      '/': =>
        unless @config.team? and @teams.indexOf(@config.team) != -1
          return @navigate('/team')
        @navigate '/on/team', encodeURIComponent(@config.team)

    Sprint.fetch()

  changingPoint: (e) ->
    if e.keyCode is 13
      e.stopPropagation()
      @commit()

  setTeam: (e) ->
    @setConfig team: @teamSelect.val()
    @setSprint()

  createSprint: =>
    if @startDateInput.val() is ""
      startDate = Date.today()
    else
      startDate = Date.parse(@startDateInput.val())
    endDate = startDate.add(@config.length)

    console.log "create ", @config.team
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
      maxNum = 0
      maxId = 0
      sprints = Sprint.findAllByAttribute 'team', @config.team
      for s in sprints
        if s.number is @config.sprint
          sprint = s
          break
        if s.number > maxNum
          maxNum = s.number
          maxId = s.id

      if not sprint? and maxId != 0
        sprint = Sprint.find maxId

      if sprint?
        @setConfig sprint: sprint.number
        @sprint = sprint
        return @navigate '/on/team', encodeURIComponent(sprint.team), 'sprint', sprint.number

      return @navigate '/on/team', encodeURIComponent(@config.team), 'create/sprint'

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
    @config extends options
    for name, value of options
      $.cookie name, value
    @config.teamEncoded = encodeURIComponent(@config.team)
    return @getConfig()

  getConfig: ->
    unless @config?
      @config =
        team: $.cookie('team') ? null
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

  render: ->
    @replace require('views/chart')(
      teams: @teams
      config: @config
      sprint: @sprint
      sprints: @sprints
      chart: @chart
    )

    @daySelect.datePicker().bind 'dpClosed', (e, dates) =>
      d = dates[0]
      if d
        d = d.asString()
        console.log d
    @startDateInput.datePicker()
    @startDateInput.bind 'dpClosed', (e, dates) =>
      console.log dates
    @daySelect.combobox()
    @

  plot: ->
    
    
module.exports = Main
