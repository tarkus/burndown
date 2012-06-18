Spine = require('spine')
Chart = require('models/chart')
Sprint = require('models/sprint')
Point = require('models/point')
$ = Spine.$

class Main extends Spine.Controller
  events:
    "click .create-sprint-btn": "createSprint"
    "change .team-select": "setTeam"
    "change #day-select": "setDay"
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
  days: []
  day: null

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
        @setConfig team: team, sprint: 0
        @setSprint()
      '/on/team/:team/sprint/:sprint': (param) =>
        team = decodeURIComponent(param.team)
        return @navigate '/team' unless @teams.indexOf(team) != -1
        @setConfig team: team, sprint: param.sprint
        console.log @config
        @setSprint()
        @getDays()
        @getChart()
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
    @setConfig team: @teamSelect.val(), sprint: 0
    @setSprint()

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
      maxNum = 0
      maxId = 0
      @sprints = Sprint.findAllByAttribute 'team', @config.team
      for s in @sprints
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

  getDays: ->
    startDate = Date.parse(@sprint.started_at)
    endDate = startDate.clone()
    endDate.addWeeks(3)
    if endDate.is().monday()
      endDate.add(-3).days()
    else
      endDate.add(-1).days()
    thisSecondWed = Date.today().moveToNthOccurrence(3, 2)
    nextSecondWed = Date.today().addMonths(1).moveToNthOccurrence(3, 2)

    addDays = (date, amount) ->
      date.add(amount).days()
      if this.is().saturday()
        adjustment = 1
      if this.is().sunday() or this.is().monday()
        adjustment = 2
      date.add(adjustment).days()
      return date

    if thisSecondWed.between(startDate, endDate)
      addDays(endDate, 3)

    if nextSecondWed.between(startDate, endDate)
      addDays(endDate, 3)

    @sprint.end_at = endDate.asString()

    @sprint.days = []
    day = startDate.clone()
    @sprint.days.push day.asString()
    for i in [0..30]
      if @sprint.days.length is @config.length
        break
      day.add(1).days()
      if day.is().saturday() or day.is().sunday()
        continue
      if day.between(day.clone().moveToNthOccurrence(3, 2), day.clone().moveToNthOccurrence(5, 2))
        continue
      @sprint.days.push day.asString()

  getChart: ->
    return unless @config.sprint?
    chart = null
    charts = Chart.findAllByAttribute 'team', @config.team
    for c in charts
      return @addChart(c) if c.sprint is @config.sprint
    if not chart?
      chart = Chart.create
        team: @config.team
        sprint: @config.sprint

  addChart: (chart) =>
    @chart = chart if chart instanceof Chart
    @getPoints()
    @plot()

  getPoints: ->
    points = []
    allPoints = Point.findAllByAttribute 'team', @config.team
    for p in allPoints
      points.push p if p.sprint = @config.sprint

    @chart.points = points

  plot: ->
    #console.log @sprint.days
    #console.log @chart.points
    
  setDay: ->
    if @daySelect.val() is ""
      if today.is().monday()
        adjustment = -3
      else if today.is().sunday()
        adjustment = -2
      else
        adjustment = -1
      @day = today.clone().add(adjustment).days().asString()
    else
      @day = @daySelect.val()
    console.log @day


  setConfig: (options) ->
    for name, value of options
      @config[name] = value
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

  preview: (e) =>
    e.preventDefault()
    point = new Point
      team: @config.team
      sprint: @config.sprint
      value: @pointInput.val()
    @plot()

  commit: (e) =>
    e.preventDefault()
    point = new Point
      team: @config.team
      sprint: @config.sprint
      value: @pointInput.val()
    @point.save()
    @plot()

  render: ->
    @replace require('views/chart')(
      teams: @teams
      config: @config
      sprint: @sprint
      sprints: @sprints
      chart: @chart
    )

    dayComboSettings = {}
    daySelectSettings =
      addClass: 'datePicker-container dropdown-toggle btn'
      renderCallback: ($td, date, month, year) ->
        if date.isWeekend()
          $td.addClass('weekend')
          $td.addClass('disabled')

        innoDaysBegin = date.clone().moveToNthOccurrence(3, 2)
        innoDaysEnd = date.clone().moveToNthOccurrence(5, 2)
        if date.between innoDaysBegin, innoDaysEnd
          $td.addClass('innodays')
          $td.addClass('disabled')

    if @sprint
      daySelectSettings.startDate = @sprint.started_at
      daySelectSettings.endDate = @sprint.end_at
      if Date.today().compareTo(Date.parse(@sprint.started_at)) >= 1
        dayComboSettings.placeholder = "Yesterday"

    @daySelect.datePicker(daySelectSettings).bind 'dpClosed', (e, dates) =>
      d = dates[0]
      if d
        d = d.asString()
        nth = @sprint.days.indexOf(d) + 1
        selectedOption = @daySelect.children('option[value=' + nth + ']')
          .attr('selected', 'selected')
        $('.combobox-container input[type=text]').val(selectedOption.text())

    @startDateInput.bind 'dpClosed', (e, dates) =>
      console.log dates

    @daySelect.combobox dayComboSettings

    @teamSelect.combobox()

    @startDateInput.datePicker
      addClass: 'datePicker-inline btn'

    @

module.exports = Main
