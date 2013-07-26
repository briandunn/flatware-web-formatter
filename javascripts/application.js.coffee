#= require vendor/zepto
#= require vendor/underscore
#= require vendor/backbone
$ ->
  source = new EventSource '/subscribe'
  window.flatware = new Flatware
  source.onmessage = (e)->
    [event, data] = JSON.parse e.data
    flatware.trigger event, data

  source.onerror = (e)-> console.log e.type
  source.onopen  = (e)-> console.log e.type

  new View.Flatware model: flatware

class Flatware extends Backbone.Model
  initialize: ->
    @jobs    = new Backbone.Collection
    @workers = new Backbone.Collection
    @on 'jobs', (jobs)=> @jobs.set jobs
    @on 'started', (work)=>
      {worker, job} = work
      @workers.add(id: worker)
      @jobs.get(job).set(workerId: worker)

    @on 'progress', (progress)=>
      {status, worker} = progress
      @workers.get(worker).set(status: status)

    # @on 'all', -> console.log arguments


View = {}

class View.Job extends Backbone.View
  initialize: ->
    @listenTo @model, 'change', @render
  render: ->
    console.log @model.attributes
    this

class View.Worker extends Backbone.View
  initialize: ->
    @listenTo @model, 'change', @render
  render: ->
    console.log @model.attributes
    this

class View.Flatware extends Backbone.View
  initialize: ->
    @listenTo @model.jobs, 'add', (job)->
      new View.Job(model: job).render().$el.appendTo 'body'

    @listenTo @model.workers, 'add', (job)->
      new View.Worker(model: job).render().$el.appendTo 'body'
