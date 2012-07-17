require 'lib/setup'

Spine = require 'spine'
Config = require('models/config')
Main = require 'controllers/main'

class ChartApp extends Spine.Controller

  constructor: ->
    super
    Spine.Route.setup(trigger: true)
    Config.fetch()
    @config = if Config.all().length is 0 then new Config else Config.all().pop()
    @teams = ['G Force', 'K Team', 'P Team']

    @main = new Main el: $('body'), teams: @teams, config: @config
    @routes
      '/on/team/:team': (param) =>
        team = decodeURIComponent(param.team)
        return @navigate '/team' unless @teams.indexOf(team) != -1
        @config.updateAttributes team: team, sprint: null
        @main.chart.active()
      '/on/team/:team/sprint/:sprint': (param) =>
        team = decodeURIComponent(param.team)
        return @navigate '/team' unless @teams.indexOf(team) != -1
        @config.updateAttributes team: team, sprint: param.sprint
       @main.chart.active()
      '/on/team/:team/create/sprint': (param) =>
        team = decodeURIComponent(param.team)
        return @navigate '/team' unless @teams.indexOf(team) != -1
        @config.updateAttributes team: team
        @main.chart.active()
      '/team': =>
        @config.updateAttributes team: null, sprint: null
        @main.teamSelect.active()
      '/': =>
        console.log "once"
        unless @config.team? and @teams.indexOf(@config.team) != -1
          return @navigate('/team')
        @navigate '/on/team', @config.team

    window.app = @

module.exports = ChartApp
    
