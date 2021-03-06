#= require vendor/zepto
#= require vendor/underscore
#= require vendor/backbone
$ ->
  source = new EventSource '/subscribe'
  window.flatware = new FWF.Flatware
  source.onmessage = (e)->
    [event, data] = JSON.parse e.data
    flatware.trigger event, data

  source.onerror = (e)-> console.log e.type
  source.onopen  = (e)-> console.log e.type

  new FWF.View.Flatware model: flatware, el: $ 'body'

window.FWF = {}

class FWF.Flatware extends Backbone.Model
  reset = ->
    @workers.remove @workers.models
    @jobs.remove @jobs.models

  initialize: ->
    @jobs    = new Backbone.Collection [], model: FWF.Job, comparator: (model)-> model.id
    @workers = new FWF.Workers []
    @on 'jobs', (jobs)=>
      reset.apply this
      @jobs.set jobs

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

    @on 'all', -> console.log arguments

class FWF.Job extends Backbone.Model
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

class FWF.Worker extends Backbone.Model
  defaults:
    status: 'waiting'
    dots: []

  completions: 0

  addStatus: (status)->
    @set dots: @get('dots').concat(status)
    @set status: status

  initialize: ->
    @on 'change', -> @get('job')?.set @pick 'status', 'dots'
    @on 'change:job', (worker, job)->
      if completed = worker.previousAttributes().job
        @trigger 'completed', worker, completed
        @completions += 1
      @trigger 'assigned', worker, job if job
      @set dots: []

class FWF.Workers extends Backbone.Collection
  model: FWF.Worker
  initialize: ->
    @on 'add', @sort
  comparator: (model)-> model.id

View = FWF.View = {}

class View.Job extends Backbone.View
  tagName: 'li'
  initialize: ->
    @listenTo @model, 'change', @render
    @listenTo @model, 'remove', @remove

  render: ->
    @$el.removeAttr('class').addClass( @model.get 'status' ).html "<p>#{@model.title()}</p>"
    _(@model.get('dots')).each (dot)=> @$el.append $('<span>').addClass dot
    this

class View.Worker extends Backbone.View
  initialize: ->
    @listenTo @model, 'change', @renderStatus
    @listenTo @model, 'remove', @remove

  tagName: 'li'

  jobList: -> @$ 'ul'

  render: ->
    @$el.append("<dl></dl><ul></ul>")
    @renderStatus()
    this

  renderStatus: ->
    @$el.find("dl").html """
      <dt>worker:</dt>
        <dd>#{@model.id}</dd>
      <dt>completions:</dt>
        <dd>#{@model.completions}</dd>
    """

class View.Transition
  distance = (from, to)->
    from.offset()[dimension] - to.offset()[dimension] for dimension in ['left', 'top']

  translate = (x, y)->
    {translateX: "#{x}px", translateY: "#{y}px"}

  constructor: (options)-> @$el = $ options.el

  render: (target)->
    [x, y] = distance target, @$el
    @$el.animate translate(x, y),
      duration: 250
      complete: =>
        @$el.remove()
          .animate translate(0, 0), duration: 0, complete: =>
            @$el.prependTo target
    this

class View.Flatware extends Backbone.View
  initialize: ->
    @finished = @$ '#finished'
    @transitions = {}
    @listenTo @model.jobs, 'add', @addJob
    @listenTo @model.workers, 'add', @addWorker

  addJob: (job)=>
    jobView = new View.Job(model: job)
    jobView.render().$el.appendTo '#waiting'
    @transitions[job.id] = transition = new View.Transition(el: jobView.el)
    @listenTo job, 'completed', =>
      transition.render @finished

  addWorker: (worker)=>
    workerView = new View.Worker(model: worker).render()
    workerView.$el.appendTo '#workers'
    @listenTo worker, 'assigned', (_, job)=>
      @transitions[job.id].render workerView.$el
