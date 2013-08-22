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

  new View.Flatware model: flatware, el: $ 'body'

class Flatware extends Backbone.Model
  initialize: ->
    @jobs    = new Backbone.Collection [], model: Job, comparator: (model)-> model.id
    @workers = new Workers []
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
      @workers.add(id: worker).get(worker).addStatus(status)

    # @on 'all', -> console.log arguments

class Job extends Backbone.Model
  defaults:
    status: 'waiting'
    dots: []

  initialize: ->
    @on 'change:worker', (_, worker)->
      if worker
        @trigger 'assigned', this, worker
      else
        @trigger 'completed', this

  title: -> @id.match(/\/(.*)\./)[1].replace /_/g, ' '

class Worker extends Backbone.Model
  defaults:
    status: 'waiting'
    dots: []

  addStatus: (status)->
    @set dots: @get('dots').concat(status)
    @set status: status

  initialize: ->
    @on 'change', -> @get('job')?.set @pick 'status', 'dots'
    @on 'change:job', (worker, job)->
      if completed = worker.previousAttributes().job
        @trigger 'completed', worker, completed
      @trigger 'assigned', worker, job if job
      @set dots: []

class Workers extends Backbone.Collection
  model: Worker
  initialize: ->
    @on 'add', @sort
  comparator: (model)-> model.id

View = {}

class View.Job extends Backbone.View
  tagName: 'li'
  initialize: ->
    @listenTo @model, 'change', @render

  render: ->
    @$el.removeAttr('class').addClass( @model.get 'status' ).html "<p>#{@model.title()}</p>"
    _(@model.get('dots')).each (dot)=> @$el.append $('<span>').addClass dot
    this

class View.Worker extends Backbone.View
  tagName: 'li'

  jobList: -> @$ 'ul'

  render: ->
    @$el.html "<p>#{@model.id}</p><ul></ul>"
    this

class View.Transition extends Backbone.View
  distance = (from, to)->
    from.offset()[dimension] - to.offset()[dimension] for dimension in ['left', 'top']

  translate = (x, y)->
    {translateX: "#{x}px", translateY: "#{y}px"}

  initialize: (options)->
    @target = options.target

  render: ->
    [x, y] = distance @target, @$el
    @$el.animate translate(x, y),
      duration: 250
      complete: =>
        @$el.remove()
          .animate translate(0, 0), duration: 0, complete: =>
            @$el.prependTo @target

class View.Flatware extends Backbone.View
  initialize: ->
    @finished = @$ '#finished'
    @jobViews = {}
    @listenTo @model.jobs, 'add', @addJob
    @listenTo @model.workers, 'add', @addWorker

  addJob: (job)=>
    jobView = new View.Job(model: job)
    @jobViews[job.id] = jobView
    jobView.render().$el.appendTo '#waiting'
    @listenTo job, 'completed', =>
      new View.Transition(el: jobView.el, target: @finished).render()

  addWorker: (worker)=>
    workerView = new View.Worker(model: worker).render()
    workerView.$el.appendTo '#workers'
    @listenTo worker, 'assigned', (_, job)=>
      new View.Transition(el: @jobViews[job.id].el, target: workerView.jobList()).render()
