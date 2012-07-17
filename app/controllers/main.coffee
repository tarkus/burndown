Spine = require('spine')
Chart = require('models/chart')
Sprint = require('models/sprint')
Point = require('models/point')
Config = require('models/config')
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
    @setConfig team: @teamSelect.val(), sprint: null
    @setSprint()

  render: ->
    @replace @template teams: @teams
    @

class Nav extends Spine.Controller

  constructor: ->
    super
    @sprint = null
    @template = require('views/nav')
    @render()

  render: ->
    @replace @template config: @config, teams: @teams, sprint: @sprint
    @

class CreateSprint extends Spine.Controller

  constructor: ->
    super
    @template = require('views/create_sprint')
    @render()

  render: =>
    @replace @template
    @

class Chart extends Spine.Controller
  events:
    "change #day-select": "setDay"
    #"keydown #point-input": "changingPoint"
    #"click .create-sprint-btn": "createSprint"
    #"focus .sprint-action": ->
    #  @sprintPointInput.removeClass('error')
    #"keydown #sprint-point-input": (e) ->
    #  @createSprint(e) if e.keyCode is 13

  elements:
    "#day-select": "daySelect"
    "#point-input": "pointInput"
    "#sprint-point-input": "sprintPointInput"
    "#chart": "chartGraph"
    "#start-date-input": "startDateInput"

  constructor: ->
    super
    @teams = @options.stack.options.teams
    @config = @options.stack.options.config
    @nav = new Nav config: @config, teams: @teams

    @active ->
      console.log 'hi'

  setDay:(e) ->
    e.preventDefault() if e

    if not @daySelect.val()? or @daySelect.val() is 'Yesterday'
      @daySelect.val(@yesterday)

    @day = @daySelect.val()

class Main extends Spine.Stack
  className: 'main stack'

  controllers:
    chart: Chart
    teamSelect: TeamSelect
    createSprint: CreateSprint

module.exports = Main
