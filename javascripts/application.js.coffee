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
        @trigger 'assigned', worker
      else
        @trigger 'completed'

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
    @on 'change:job', -> @set dots: []

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
    @listenTo @model, 'assigned', @assign
    @listenTo @model, 'completed', @completed

  assign: (worker)->
    left = worker.get('left') - @$el.offset().left
    top  = worker.get('top')  - @$el.offset().top
    @$el.animate {translateX: "#{left}px", translateY: "#{top}px"},
      duration: 500
      complete: =>
        @$el.remove()
          .animate {translateX: "0px", translateY: "0px"}, duration: 0, complete: =>
            @$el.appendTo $('#workers > li').eq(worker.id).find 'ul'


  completed: ->
    left = $('#finished').offset().left - @$el.offset().left
    top  = $('#finished').offset().top  - @$el.offset().top
    console.log left, top
    @$el.animate {translateX: "#{left}px", translateY: "#{top}px"},
      duration: 500
      complete: =>
        @$el.remove()
          .animate {translateX: "0px", translateY: "0px"}, duration: 0, complete: =>
            @$el.prependTo $ '#finished'

  render: ->
    @$el.addClass( @model.get 'status' ).html "<p>#{@model.title()}</p>"
    _(@model.get('dots')).each (dot)=> @$el.append $('<span>').addClass dot
    this

class View.Worker extends Backbone.View
  tagName: 'li'

  render: ->
    @$el.html "<p>#{@model.id}</p><ul></ul>"
    this

class View.Flatware extends Backbone.View
  initialize: ->
    @listenTo @model.jobs, 'add', (job)->
      new View.Job(model: job).render().$el.appendTo '#waiting'

    @listenTo @model.workers, 'add', (job)->
      workerView = new View.Worker(model: job).render()
      workerView.$el.appendTo '#workers'
      workerView.model.set workerView.$el.offset()
