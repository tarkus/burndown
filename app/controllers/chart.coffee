Spine = require('spine')
Chart = require('models/chart')
Sprint = require('models/sprint')
Point = require('models/point')
$ = Spine.$

drawBurndown = (el, days, point, points) ->
  stepY = 10
  width  = 840
  height = 360
  textHeight = 60

  top  = (el.height()- textHeight - height) / 2 + textHeight
  left = (el.width() - width) / 2

  axisX = []
  axisY = []

  sprintX = []
  sprintY = []

  bugfixX = []
  bugfixY = []

  dashX = []
  dashY = []

  dashX.push i for i in [0..days]
  dashY.push point * i / days for i in [days..0]
  axisX.push "Day " + i for i in [1..days]
  axisX.push "Done"
  maxY = Math.ceil(point / stepY) + 1
  axisY.push (i * stepY).toString() for i in [0..maxY]

  r = Raphael(el[0].offsetLeft, el[0].offsetTop, el.width(), el.height())

  r.text(100, 50, 'G Force Sprint 1 Burndown')

  if points.length >= 2
    value = point
    for p in points
      if p.line is 'sprint'
        value = value - p.value
        sprintX.push parseInt(p.day)
        sprintY.push value
      if p.line is 'bugfix'
        bugfixX.push p.day
        bugfixY.push p.value

    console.log sprintX, sprintY

  chart = r.linechart(left, top, width, height, [
    dashX
    sprintX
    bugfixX
    [0, days]
  ], [
    dashY
    sprintY
    bugfixY
    [maxY * stepY, 0]
  ], {
    nostroke: false
    axis: '0 0 0 0'
    symbol: ['circle', 'circle', 'squarel', '']
    colors: ['#4684EE', '#DC3912', '#DC3912', '']
    dash: ['-', '', '']
    #gutter: 20
    #smooth: true
  })

  axisLeft = chart[0][3].attrs.path[0][1]
  axisTop = chart[0][3].attrs.path[0][2]
  axisRight = chart[0][3].attrs.path[1][1]
  axisBottom = chart[0][3].attrs.path[1][2]
  axisXLength = axisRight - axisLeft
  axisYLength = axisBottom - axisTop

  X = Raphael.g.axis axisLeft, axisBottom, axisXLength, null, null, axisX.length - 1, 0, axisX, '+', 2, r
  X.attr stroke: '#E4E4E4'

  Y = Raphael.g.axis axisLeft, axisBottom, axisYLength, null, null, axisY.length - 1, 1, axisY, '+', 2, r
  Y.attr stroke: '#E4E4E4'

  for p in X.attrs.path[2..] by 2
    path = 'M' + p[1] + ',' + axisTop + 'V' + axisBottom
    vpath = r.path path
    vpath.attr
      stroke: '#E4E4E4'

  for p, i in Y.attrs.path[4..] by 2
    path = 'M' + axisLeft + ',' + p[2] + 'H' + axisRight
    hpath = r.path path
    hpath.attr
      stroke: '#E4E4E4'

  chart.toFront()


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
  day: null

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
      point: parseInt(@sprintPointInput.val())
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
    Point.fetch()
    @plot()

  plot: (e) =>
    console.log "count"
    e.preventDefault() if e instanceof Event

    @chart.points = []
    allPoints = Point.findAllByAttribute 'team', @chart.team
    for p in allPoints
      @chart.points.push p if p.sprint is @config.sprint

    if @chart.points.length is 0
      @setDay()
      point =  new Point
        team: @sprint.team
        sprint: @sprint.number
        line: 'sprint'
        value: 0
        day: @day or 0

      point.chart = @chart
      @chart.points.push point
      point.save()

    @render()


  setDay:(e) ->
    e.preventDefault() if e

    if not @daySelect.val()? or @daySelect.val() is 'Yesterday'
      @daySelect.val(@yesterday)

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
    e.preventDefault() if e instanceof Event
    @setDay()
    point = new Point
      team: @sprint.team
      sprint: @sprint.number
      value: @pointInput.val()
      line: 'sprint'
      day: @day
    @plot()
    return point

  commit: (e) =>
    e.preventDefault() if e instanceof Event
    point = @preview()
    point.save()

  render: ->
    @replace require('views/chart')(
      teams: @teams
      config: @config
      sprint: @sprint
      sprints: @sprints
      chart: @chart
      today: @today
      yesterday: @yesterday
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

    $("svg").addClass('hidden')
    if @chartGraph[0] and @chart instanceof Chart
      console.log 'loop?'
      $("svg").removeClass('hidden')
      drawBurndown(@chartGraph, @config.length, @sprint.point, @chart.points)
    @

module.exports = Main
