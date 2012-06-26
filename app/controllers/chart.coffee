Spine = require('spine')
Chart = require('models/chart')
Sprint = require('models/sprint')
Point = require('models/point')
$ = Spine.$


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
    Chart.bind 'create', @setChart
    Sprint.bind 'create', @setSprint
    Point.bind 'fetch', @getPoints

    @getConfig()

    @routes
      '/on/team/:team': (param) =>
        team = decodeURIComponent(param.team)
        return @navigate '/team' unless @teams.indexOf(team) != -1
        @setConfig team: team, sprint: null
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
    Point.fetch()

  drawBurndown: (el, days, point, points) ->
    stepY = 20
    width  = 840
    height = 380
    textHeight = 50

    top  = (el.height()- textHeight - height) / 2 + textHeight
    left = (el.width() - width) / 2

    sprintX = []
    sprintY = []

    bugfixX = []
    bugfixY = []

    if @r?
      @r.clear()
      r = @r
    else
      r = Raphael(el[0].offsetLeft, el[0].offsetTop, el.width(), el.height())
      @r = r
    r.text(100, 30, 'G Force Sprint 1 Burndown')

    axisX = []
    axisY = []

    dashX = []
    dashY = []

    dashX.push i for i in [0..days]
    dashY.push point * i / days for i in [days..0]
    axisX.push "Day " + i for i in [1..days]
    axisX.push "Done"
    maxY = Math.ceil(point / stepY) + 1
    axisY.push (i * stepY).toString() for i in [0..maxY]
    chart = r.linechart(left, top, width, height, [
      dashX
      [0, days]
    ], [
      dashY
      [maxY * stepY, 0]
    ], {
      nostroke: false
      axis: '0 0 0 0'
      symbol: ['circle', '']
      colors: ['#4684EE', '']
      dash: ['-', '']
      #gutter: 20
      #smooth: true
    })

    axisLeft = chart.lines[1].attrs.path[0][1]
    axisTop = chart.lines[1].attrs.path[0][2]
    axisRight = chart.lines[1].attrs.path[1][1]
    axisBottom = chart.lines[1].attrs.path[1][2]
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
      coord =
        top: axisTop
        left: axisLeft
        right: axisRight
        bottom: axisBottom
        width: axisXLength
        height: axisYLength
        max: maxY * stepY

    @sprintLine.remove() if @sprintLine
    @circles.remove() if @circles
    @circles = r.set()
    path = ""
    path += chart.lines[0].attrs.path[0].join(',')
    c = r.circle(chart.lines[0].attrs.path[0][1],
      chart.lines[0].attrs.path[0][2], 5.5)
    .attr stroke: '#DC3912', fill: '#DC3912', smooth: true
    @circles.push c
    for p, i in points
      continue if p.day is 0
      point -= p.value
      x = chart.lines[0].attrs.path[parseInt(p.day)][1]
      y = top + ( 1 - point / coord.max ) * coord.height
      path += ['L', x, y].join(',')
      c = r.circle(x, y, 5.2).attr stroke: '#DC3912', fill: '#DC3912', smooth: true
      @circles.push c
    line = r.path path
    line.attr
      stroke: '#DC3912'
      'stroke-width': '2'
      'stroke-linecap': 'round'
      'stroke-linejoin': 'round'

      #@sprintLine.toFront()

  changingPoint: (e) ->
    if e.keyCode is 13
      e.stopPropagation()
      @commit()

  setTeam: (e) ->
    e.preventDefault()
    @setConfig team: @teamSelect.val(), sprint: null
    @setSprint()

  createSprint: (e) =>
    e.preventDefault()
    if @startDateInput.val() is ""
      startDate = Date.today()
    else
      startDate = Date.parseExact(@startDateInput.val(), 'd/M/yyyy')

    [startDate, endDate] = @adjustSprintDate(startDate)
    
    unless parseInt(@sprintPointInput.val()) > 0
      return @sprintPointInput.addClass('error')

    @sprints = Sprint.findAllByAttribute 'team', @config.team
    max = -1
    for s in @sprints
      max = s.number if s.number > max
    Sprint.create
      team: @config.team
      number: max + 1
      started_at: startDate.asString()
      point: parseInt(@sprintPointInput.val())
      end_at: endDate.asString()

  setSprint: (sprint) =>
    maxNum = -1
    maxId = null
    @sprints = Sprint.findAllByAttribute 'team', @config.team
    @points = []
    unless sprint instanceof Sprint
      for s in @sprints
        if s.number is parseInt(@config.sprint)
          sprint = s
          break
        if s.number > maxNum
          maxNum = s.number
          maxId = s.id

      if not sprint? and maxId?
        sprint = Sprint.find maxId

    if sprint?
      @setConfig sprint: sprint.number
      @sprint = sprint
      return @navigate '/on/team', encodeURIComponent(sprint.team), 'sprint', sprint.number

    return @navigate '/on/team', encodeURIComponent(@config.team), 'create/sprint'

  adjustSprintDate: (date) ->
    if typeof date is 'string'
      date = Date.parseExact(date, 'd/M/yyyy')

    if date instanceof Date
      startDate = date.clone()
    else
      return false

    if startDate.is().sunday() or startDate.is().saturday()
      startDate.moveToDayOfWeek(1)

    innoDaysBegin = startDate.clone().moveToNthOccurrence(3, 2)
    innoDaysEnd = innoDaysBegin.clone().addDays(2)
    if startDate.between(innoDaysBegin, innoDaysEnd)
      startDate.moveToDayOfWeek(1)

    endDate = startDate.clone()
    days = 1
    while days < @config.length
      endDate.addDays(1)
      if endDate.is().saturday()
        endDate.moveToDayOfWeek(0)
        continue
      days += 1

    addDays = (adate, amount) ->
      adate.add(amount).days()
      if adate.is().saturday() or adate.is().sunday() or adate.is().monday()
        adate.add(2).days()
      return adate

    thisInnoDays = startDate.clone().moveToNthOccurrence(3, 2)
    nextInnoDays = startDate.clone().addMonths(1).moveToNthOccurrence(3, 2)

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
      return @setChart(c) if c.sprint is @sprint.number
    if not chart?
      Chart.create
        team: @sprint.team
        sprint: @sprint.number

  setChart: (chart) =>
    @chart = chart

  plot: (e) =>
    e.preventDefault() if e instanceof Event
    @getPoints()
    @render()

  getPoints: =>
    return unless @chart?
    @points = []
    allPoints = Point.findAllByAttribute 'team', @chart.team
    @setDay()
    point = null
    for p in allPoints
      if p.sprint is @chart.sprint
        point = p if p.day is @day
        @points.push p

    if @pointInput.val()
      unless point?
        point = new Point
          team: @chart.team
          sprint: @chart.sprint
          value: @pointInput.val()
          line: 'sprint'
          day: @day
        @points.push point
        point.save()
      else
        point.value = @pointInput.val()
        point.save()

    if @points.length > 0
      @points.sort (a, b) ->
        return parseInt(a.day) - parseInt(b.day)
    else
      point =  new Point
        team: @chart.team
        sprint: @chart.sprint
        line: 'sprint'
        value: 0
        day: @day or 0
      @points.push point
      point.save()

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

  commit: (e) =>
    e.preventDefault() if e instanceof Event
    @plot()

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
    skipWeekendAndInnoDays = ($td, date, month, year) ->
      if date.isWeekend()
        $td.addClass('weekend')
        $td.addClass('disabled')

      innoDaysBegin = date.clone().moveToNthOccurrence(3, 2)
      innoDaysEnd = innoDaysBegin.clone().addDays(2)
      if date.between(innoDaysBegin, innoDaysEnd)
        $td.addClass('innodays')
        $td.addClass('disabled')

    daySelectSettings =
      addClass: 'datePicker-container dropdown-toggle btn'
      renderCallback: skipWeekendAndInnoDays

    if @sprint
      daySelectSettings.startDate = @sprint.started_at
      daySelectSettings.endDate = @sprint.end_at
      if Date.today().compareTo(Date.parseExact(@sprint.started_at, 'd/M/yyyy')) >= 1
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
      startDate: '01/01/2000'
      renderCallback: skipWeekendAndInnoDays

    @startDateInput.bind 'dpClosed', (e, dates) =>
      d = dates[0]
      if d
        @startDateInput.val(d.asString())
        $('#start-date').text(d.asString())

    $("svg").css 'display', 'none'
    if @chartGraph[0] and @sprint instanceof Sprint
      $("svg").css 'display', ''
      @drawBurndown(@chartGraph, @config.length, @sprint.point, @points)
    @

module.exports = Main
