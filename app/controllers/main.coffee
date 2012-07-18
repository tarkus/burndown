Spine = require 'spine'
Point  = require 'models/point'
Sprint = require 'models/sprint'
Config = require 'models/config'
$ = Spine.$

class TeamSelect extends Spine.Controller

  events:
    "change .team-select": "setTeam"

  elements:
    ".team-select": "teamSelect"

  constructor: ->
    super
    @teams = @options.stack.options.teams
    @template = require('views/team_select')
    @render()

  setTeam: (e) =>
    e.preventDefault()
    @stack.config.updateAttributes team: @teamSelect.val(), sprint: null
    @navigate '/on/team', @teamSelect.val()

  render: ->
    @html @template teams: @teams
    @teamSelect.combobox()
    @

class CreateSprint extends Spine.Controller

  events:
    "click .create-sprint-btn": "createSprint"
    "focus .sprint-action": ->
      @pointInput.removeClass('error')
    "keydown .point-input": (e) ->
      @createSprint() if e.keyCode is 13

  elements:
    ".nav": "navDiv"
    ".point-input": "pointInput"
    ".date-input": "startDateInput"
    ".date": "startDateDiv"

  constructor: ->
    super
    @active ->
      @render()
      console.log @el

    @template = require('views/create_sprint')
    @nav = new Nav stack: @stack
    @render()

  createSprint: (e) =>
    e.preventDefault()
    if @startDateInput.val() is ""
      startDate = Date.today()
    else
      startDate = Date.parseExact(@startDateInput.val(), 'd/M/yyyy')

    [startDate, endDate] = adjustSprintDate(startDate, @stack.options.length)
    
    unless parseInt(@pointInput.val()) > 0
      return @pointInput.addClass('error')

    @sprints = Sprint.findAllByAttribute 'team', @stack.config.team
    max = -1
    for s in @sprints
      max = s.number if s.number > max
    sprint = new Sprint
      team: @stack.config.team
      number: max + 1
      started_at: startDate.asString()
      point: parseInt(@pointInput.val())
      end_at: endDate.asString()
    sprint.save =>
      @navigate '/on/team', encodeURIComponent(sprint.team), 'sprint', sprint.number, trigger: true

  render: ->
    @html @template
      config: @stack.config

    @navDiv.html @nav.render().el

    @startDateInput.datePicker
      addClass: 'datePicker-inline btn'
      startDate: '01/01/2000'
      renderCallback: skipWeekendAndInnoDays

    @startDateInput.bind 'dpClosed', (e, dates) =>
      d = dates[0]
      return unless d?
      @startDateDiv.text(d.asString())
      @startDateInput.val(d.asString())
    @

class Nav extends Spine.Controller

  constructor: ->
    super
    @sprint = null
    @sprints = Sprint.findAllByAttribute 'team', @stack.config.team
    @template = require('views/nav')

  render: ->
    @html @template
      config: @stack.config
      teams: @stack.teams
      sprint: @sprint
      sprints: @sprints
    @


class Chart extends Spine.Controller

  events:
    "click .commit": "plot"
    "keydown .point-input": (e) ->
      @plot() if e.keyCode is 13

  elements:
    ".nav": "navDiv"
    ".day-select": "daySelect"
    ".point-input": "pointInput"
    "#chart": "chartGraph"

  constructor: ->
    super

    @points = []
    @sprint = null
    @today = null
    @yesterday = null

    @template = require('views/chart')

    @nav = new Nav stack: @stack

    @active =>
      @getSprint()

    Point.bind 'refresh', @getPoints
    Sprint.bind 'refresh', @getSprint

    Point.fetch()
    Sprint.fetch()

  getSprint: (sprint) =>
    maxNum = -1
    maxId = null
    @points = []
    unless sprint instanceof Sprint
      sprint = null
      sprints = Sprint.findAllByAttribute 'team', @stack.config.team
      for s in sprints
        if s.team is @stack.config.team and
        s.number is parseInt(@stack.config.sprint)
          sprint = s
          break
        if s.number > maxNum
          maxNum = s.number
          maxId = s.id

      if not (sprint instanceof Sprint) and maxId?
        sprint = Sprint.find maxId

    if sprint?
      @sprint = sprint
      console.log "setSprint with", sprint
      @stack.config.updateAttributes sprint: sprint.number
      if parseInt(@stack.config.sprint) is sprint.number
        @getSprintDays()
        return @render()
      #return @navigate '/on/team', encodeURIComponent(sprint.team), 'sprint', sprint.number, trigger: true

    #return @navigate '/on/team', encodeURIComponent(@stack.config.team), 'create/sprint'

  getSprintDays: ->
    @today = null
    @yesterday = null
    [startDate, endDate] = adjustSprintDate(@sprint.started_at, @stack.options.days)

    @sprint.started_at = startDate.asString()
    @sprint.end_at = endDate.asString()
    @sprint.save()

    @sprint.days = []
    day = startDate.clone()
    @sprint.days.push day.asString()
    for i in [0..30]
      if @sprint.days.length is @stack.options.days
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

  getPoints: =>
    point = null
    @points = []
    return unless @stack.config.team is not ''
    allPoints = Point.findAllByAttribute 'team', @stack.config.team

    if not @daySelect.val()? or @daySelect.val() is 'Yesterday'
      @daySelect.val(@yesterday)

    day = @daySelect.val()

    for p in allPoints
      if p.sprint is @stack.config.sprint
        point = p if p.day is day
        @points.push p

    console.log @points

    if @pointInput.val()
      unless point?
        point = new Point
          team: @stack.config.team
          sprint: @stack.config.sprint
          value: @pointInput.val()
          line: 'sprint'
          day: day
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
        team: @stack.config.team
        sprint: @stack.config.sprint
        line: 'sprint'
        value: 0
        day: day or 0
      @points.push point
      point.save()

  plot: (e) =>
    @getPoints()
    #@draw(@chartGraph, @stack.options.days, @sprint.point, @points)

  render: ->
    @html @template
      config: @stack.config
      sprint: @sprint
      today: @today
      yesterday: @yesterday

    @navDiv.html @nav.render().el

    dayComboSettings = {}

    daySelectSettings =
      addClass: 'datePicker-container dropdown-toggle btn'
      renderCallback: skipWeekendAndInnoDays

    daySelectSettings.startDate = @sprint.started_at
    daySelectSettings.endDate = @sprint.end_at
    if Date.today().compareTo(Date.parseExact(@sprint.started_at, 'd/M/yyyy')) >= 1
      dayComboSettings.placeholder = "Yesterday"

    @daySelect.datePicker(daySelectSettings).bind 'dpClosed', (e, dates) =>
      d = dates[0]
      return unless d?
      d = d.asString()
      nth = @sprint.days.indexOf(d) + 1
      selectedOption = @daySelect.children('option[value=' + nth + ']')
        .attr('selected', 'selected')
      $('.combobox-container input[type=text]').val(selectedOption.text())

    @daySelect.combobox dayComboSettings


    #@draw(@chartGraph, @stack.options.days, @sprint.point, @points)
    @

  draw: (el, days, point, points) ->
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

    r = Raphael('chart', el.width(), el.height())
    r.text(100, 30, 'G Force Sprint #1 Burndown Chart')

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
      console.log point
      console.log coord.max
      console.log 1 - (point / coord.max)
      console.log coord.top
      console.log ( 1 - point / coord.max ) * coord.height
      console.log coord.top + ( 1 - point / coord.max ) * coord.height
      x = chart.lines[0].attrs.path[parseInt(p.day)][1]
      y = coord.top + ( 1 - point / coord.max ) * coord.height
      path += ['L', x, y].join(',')
      console.log path
      c = r.circle(x, y, 5.5).attr stroke: '#DC3912', fill: '#DC3912', smooth: true
      @circles.push c
    line = r.path path
    line.attr
      stroke: '#DC3912'
      'stroke-width': '2'
      'stroke-linecap': 'round'
      'stroke-linejoin': 'round'

    window.chart = chart


class Main extends Spine.Stack
  className: 'main stack'

  controllers:
    teamSelect: TeamSelect
    createSprint: CreateSprint
    chart: Chart

skipWeekendAndInnoDays = ($td, date, month, year) ->
  if date.isWeekend()
    $td.addClass('weekend')
    $td.addClass('disabled')

  innoDaysBegin = date.clone().moveToNthOccurrence(3, 2)
  innoDaysEnd = innoDaysBegin.clone().addDays(2)
  if date.between(innoDaysBegin, innoDaysEnd)
    $td.addClass('innodays')
    $td.addClass('disabled')


adjustSprintDate = (date, length) ->
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
  while days < length
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

module.exports = Main
