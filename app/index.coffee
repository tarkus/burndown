require 'lib/setup'

Spine  = require 'spine'
Main   = require 'controllers/main'
Config = require 'models/config'

Spine.Controller.include
  activate: ->
    @el.addClass('active').css('display', '')
    @
  deactivate: ->
    @el.removeClass('active').css('display', 'none')
    @

class ChartApp extends Spine.Controller

  constructor: ->
    super
    Config.fetch()
    @config = if Config.all().length is 0 then new Config else Config.all().pop()
    @teams = ['G Force', 'K Team', 'P Team']
    @days = 10

    @routes
      '/on/team/:team': (param) =>
        team = decodeURIComponent(param.team)
        return @navigate '/team' unless @teams.indexOf(team) != -1
        @config.updateAttributes team: team, sprint: null
        @main.chart.getSprint()
        if @main.chart.sprint?
          @config.updateAttributes sprint: @main.chart.sprint.number
          @navigate '/on/team', @config.team, 'sprint', @config.sprint
        else
          @navigate '/on/team', @config.team, 'create/sprint'
      '/on/team/:team/sprint/:sprint': (param) =>
        team = decodeURIComponent(param.team)
        return @navigate '/team' unless @teams.indexOf(team) != -1
        @config.updateAttributes team: team, sprint: param.sprint
        @main.chart.active()
      '/on/team/:team/create/sprint': (param) =>
        team = decodeURIComponent(param.team)
        return @navigate '/team' unless @teams.indexOf(team) != -1
        @config.updateAttributes team: team
        @main.createSprint.active()
      '/team': =>
        console.log '1'
        @config.updateAttributes team: null, sprint: null
        @main.teamSelect.active()
      '/': =>
        unless @config.team? and @teams.indexOf(@config.team) != -1
          return @navigate('/team')
        @navigate '/on/team', @config.team

    @main = new Main el: $('#main'), teams: @teams, config: @config, days: @days
    Spine.Route.setup(trigger: true)

module.exports = ChartApp
    
