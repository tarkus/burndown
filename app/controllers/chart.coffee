Spine = require('spine')
Chart = require('models/chart')
Sprint = require('models/sprint')
Point = require('models/point')
$ = Spine.$

drawBurndown = (el, days, points) ->
  x = el[0].offsetLeft
  y = el[0].offsetTop
  offsetX = 20
  offsetY = 20
  width  = el.width() - offsetX * 2
  height = el.height() - offsetY * 2
  axisX = []
  axisY = []
  axisX.push i for i in [0..days]
  axisY.push i for i in [6..0]
  console.log axisY
  r = Raphael(x, y, el.width(), el.height())
  chart = r.linechart(20, 20, width, height, [
    [0, 1, 2, 3, 4, 5]
    [0, 15]
    [0, 15]
  ], [
    [100, 95, 83, 75, 65]
    [100, 0]
    [120, 0]
  ], {
    nostroke: false
    axis: '0 0 1 1'
    symbol: ['circle', '', 'circle']
    colors: ['#469bd4', 'gray', 'transparent']
    dash: ['', '-']
    #smooth: true
  }).hoverColumn ()->
    ###
    @tags = r.set()
    for i in [0...y]
      @tags.push(r.tag(@x, @y[i], @values[i], 160, 10).insertBefore(@).attr([{ fill: "#fff" }, { fill: @symbols[i].attr("fill") }]))
    ###
  , () ->
    @tags and @tags.remove()

  axisItems = chart.axis[0].text.items
  console.log axisItems

class Main extends Spine.Controller
  events:
    "change .team-select": "setTeam"
    "change #day-select": "setDay"
    "keydown #point-input": "changingPoint"
    "click .create-sprint-btn": "createSprint"
    "focus .sprint-action": ->
      @sprintPointInput.removeClass('error')
    "keydown #sprint-point-input": (e) ->
      @createSprint(e) if e.keyCode is 13

  elements:
    ".team-select": "teamSelect"
    "#day-select": "daySelect"
    "#point-input": "pointInput"
    "#sprint-point-input": "sprintPointInput"
    "#chart": "chartGraph"
    "#start-date-input": "startDateInput"

  sprint: null
  sprints: []
  chart: null
  points: []
  days: []
  today: null
  yesterday: null

  constructor: ->
    super
    Chart.bind 'create', @addChart
    Chart.bind 'update refresh', @plot
    Sprint.bind 'create', @setSprint

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
        @setSprint()
        if @sprint
          @getSprintDays()
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
    e.preventDefault()
    if e.keyCode is 13
      e.stopPropagation()
      @commit()

  setTeam: (e) ->
    e.preventDefault()
    @setConfig team: @teamSelect.val(), sprint: 0
    @setSprint()

  createSprint: (e) =>
    e.preventDefault()
    if @startDateInput.val() is ""
      startDate = Date.today()
    else
      startDate = Date.parse(@startDateInput.val())

    [startDate, endDate] = @adjustSprintDate(startDate)
    
    unless parseInt(@sprintPointInput.val()) > 0
      return @sprintPointInput.addClass('error')

    Sprint.create
      team: @config.team
      number: parseInt(@config.sprint) ? 0
      started_at: startDate.asString()
      points: parseInt(@sprintPointInput.val())
      end_at: endDate.asString()

  addSprint: (sprint) =>
    @sprint = sprint
    console.log Date.compare Date.today(), Date.parse(@sprint.started_at)
    chart = Chart.findByAttribute
      team: @sprint.team
      sprint: @sprint.number

    console.log chart

  setSprint: (sprint) =>
    @sprints = Sprint.findAllByAttribute 'team', @config.team
    unless sprint instanceof Sprint
      maxNum = 0
      maxId = 0
      for s in @sprints
        if s.number is parseInt(@config.sprint)
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

  adjustSprintDate: (date) ->
    if typeof date is 'string'
      date = Date.parse(date)

    if date instanceof Date
      startDate = date.clone()
    else
      return false


    if startDate.is().sunday()
      adjustment = 1
    else if startDate.is().saturday()
      adjustment = 2

    if adjustment?
      startDate.add(adjustment).days()

    innoDaysBegin = startDate.clone().moveToNthOccurrence(3, 2)
    innoDaysEnd = startDate.clone().moveToNthOccurrence(5, 2)
    if startDate.between(innoDaysBegin, innoDaysEnd)
      startDate.moveToDayOfWeek(0)

    endDate = startDate.clone()
    endDate.add(20).days()
    if endDate.is().sunday() or endDate.is().saturday()
      adjustment = 2
      endDate.add(adjustment).days()
    thisInnoDays = startDate.clone().moveToNthOccurrence(3, 2)
    nextInnoDays = startDate.clone().addMonths(1).moveToNthOccurrence(3, 2)

    addDays = (adate, amount) ->
      adate.add(amount).days()
      if adate.is().saturday() or adate.is().sunday() or adate.is().monday()
        adate.add(2).days()
      return adate

    if thisInnoDays.between(startDate, endDate)
      addDays(endDate, 3)

    if nextInnoDays.between(startDate, endDate)
      addDays(endDate, 3)

    return [startDate, endDate]

  getSprintDays: ->
    @today = null
    @yesterday = null
    [startDate, endDate] = @adjustSprintDate(@sprint.started_at)

    @sprint.started_at = startDate.asString()
    @sprint.end_at = endDate.asString()
    @sprint.save()

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

    today = @sprint.days.indexOf(Date.today().asString())
    return if today == -1
    nth = today + 1
    if nth is 1
      @today = '1st'
    else if nth is 2
      @today = '2nd'
    else if nth is 3
      @today = '3rd'
    else
      @today = nth + "th"
    @yesterday = if nth > 1 then nth - 1

  getChart: ->
    chart = null
    charts = Chart.findAllByAttribute 'team', @config.team
    for c in charts
      return @addChart(c) if c.sprint is @config.sprint
    if not chart?
      Chart.create
        team: @config.team
        sprint: @config.sprint

  addChart: (chart) =>
    @chart = chart
    @plot()

  plot: (e) =>
    if e instanceof Event
      e.preventDefault()

    @chart.points = []
    allPoints = Point.findAllByAttribute 'team', @config.team
    for p in allPoints
      @chart.points.push p if p.sprint = @config.sprint

    if @chart.points.length is 0
      point =  new Point
        team: @sprint.team
        sprint: @sprint.number
        line: 'sprint'
        value: @sprint.points

      point.chart = @chart
      @chart.points.push point
      point.save()


    #console.log @sprint.days
    #console.log @chart.points
    
  setDay:(e) ->
    e.preventDefault()
    if @daySelect.val() is ""
      @daySelect.val(@yesterday)
    else
      @day = @daySelect.val()


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
      today: @today
    )

    dayComboSettings = {}
    skipWeenkendAndInnoDays = ($td, date, month, year) ->
      if date.isWeekend()
        $td.addClass('weekend')
        $td.addClass('disabled')

      innoDaysBegin = date.clone().moveToNthOccurrence(3, 2)
      innoDaysEnd = date.clone().moveToNthOccurrence(5, 2)
      if date.between innoDaysBegin, innoDaysEnd
        $td.addClass('innodays')
        $td.addClass('disabled')

    daySelectSettings =
      addClass: 'datePicker-container dropdown-toggle btn'
      renderCallback: skipWeenkendAndInnoDays

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

    @daySelect.combobox dayComboSettings

    @teamSelect.combobox()

    @startDateInput.datePicker
      addClass: 'datePicker-inline btn'
      renderCallback: skipWeenkendAndInnoDays

    @startDateInput.bind 'dpClosed', (e, dates) =>
      d = dates[0]
      if d
        @startDateInput.val(d.asString())
        $('#start-date').text(d.asString())


    if @chartGraph[0] and @sprint instanceof Sprint
      drawBurndown(@chartGraph, @config.length, @sprint.points)

    @

module.exports = Main
