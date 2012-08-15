require 'lib/setup'

Spine  = require 'spine'
Main   = require 'controllers/main'
Config = require 'models/config'
Sprint = require 'models/sprint'
Point  = require 'models/point'

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
    Point.fetch()
    Sprint.fetch()

    @config = if Config.all().length is 0 then new Config else Config.all().pop()
    @teams = ['G Force', 'K Team', 'P Team']
    @days = 10

    @routes
      '/on/team/:team': (param) =>
        team = decodeURIComponent(param.team)
        return @navigate '/team' unless @teams.indexOf(team) != -1
        @config.updateAttributes team: team, sprint: null
        maxId = null
        maxNum = -1
        sprints = Sprint.findAllByAttribute 'team', @config.team
        for s in sprints
          if s.number > maxNum
            maxNum = s.number
            maxId = s.id
        if maxId?
          sprint = Sprint.find maxId
          @config.updateAttributes sprint: sprint.number
          @navigate '/on/team', @config.team, 'sprint', @config.sprint
        else
          @navigate '/on/team', @config.team, 'create/sprint'
      '/on/team/:team/sprint/:sprint': (param) =>
        team = decodeURIComponent(param.team)
        return @navigate '/team' unless @teams.indexOf(team) != -1
        @main.chart.sprint = null
        sprint = null
        sprints = Sprint.findAllByAttribute 'team', @config.team
        for s in sprints
          if s.team is @config.team and
          s.number is parseInt(param.sprint)
            sprint = s
            break
          if s.number > maxNum
            maxNum = s.number
            maxId = s.id
        if sprint?
          @main.chart.sprint = sprint
          @config.updateAttributes team: team, sprint: param.sprint
          @main.chart.active()
        else
          @navigate '/on/team', @config.team, 'create/sprint'
      '/on/team/:team/create/sprint': (param) =>
        team = decodeURIComponent(param.team)
        return @navigate '/team' unless @teams.indexOf(team) != -1
        @config.updateAttributes team: team, sprint: null
        @main.createSprint.active()
      '/team': =>
        @config.updateAttributes team: null, sprint: null
        @main.teamSelect.active()
      '/hours_estimate': =>
        unless @config.team? and @teams.indexOf(@config.team) != -1
          return @navigate('/team')
        @main.hourEstimate.active()
      '/': =>
        unless @config.team? and @teams.indexOf(@config.team) != -1
          return @navigate('/team')
        @navigate '/on/team', @config.team

    @main = new Main el: $('#main'), teams: @teams, config: @config, days: @days
    Spine.Route.setup(trigger: true)

module.exports = ChartApp
    
