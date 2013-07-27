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
    @jobs    = new Backbone.Collection [], model: Job
    @workers = new Backbone.Collection [], model: Worker
    @on 'jobs', (jobs)=> @jobs.set jobs
    @on 'started', (work)=>
      {worker, job} = work
      worker = @workers.add(id: worker).get(worker)
      job    = @jobs.add(id: job).get(job)
      job.set worker: worker
      worker.set job: job

    @on 'finished', (work)=>
      {worker, job} = work
      worker = @workers.add(id: worker).get(worker)
      job    = @jobs.add(id: job).get(job)
      job.set worker: null
      worker.set job: null

    @on 'progress', (progress)=>
      {status, worker} = progress
      @workers.add(id: worker).get(worker).set(status: status)

    # @on 'all', -> console.log arguments

class Job extends Backbone.Model
  defaults:
    status: 'waiting'

class Worker extends Backbone.Model
  defaults:
    status: 'waiting'
  initialize: ->
    @on 'change:status change:job', -> @get('job')?.set status: @get 'status'

View = {}

class View.Job extends Backbone.View
  tagName: 'li'
  initialize: ->
    @listenTo @model, 'change', @render
    @listenTo @model, 'change:worker', @remove
  render: ->
    @$el.addClass( @model.get 'status' ).html @model.id
    this

class View.Worker extends Backbone.View
  tagName: 'li'
  initialize: ->
    @listenTo @model, 'change', @render

  render: ->
    @$el.html "<p>#{@model.id}</p>"
    if job = @model.get 'job'
      jobList = $ '<ul>'
      @$el.append jobList
      new View.Job(model:job).render().$el.appendTo jobList
    this

class View.Flatware extends Backbone.View
  initialize: ->
    @listenTo @model.jobs, 'add', (job)->
      new View.Job(model: job).render().$el.appendTo '#waiting'

    @listenTo @model.jobs, 'change:worker', (job, worker)->
      unless worker
        new View.Job(model: job).render().$el.appendTo '#finished'

    @listenTo @model.workers, 'add', (job)->
      new View.Worker(model: job).render().$el.appendTo '#workers'
