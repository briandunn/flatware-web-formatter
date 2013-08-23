#= require application
describe 'Worker', ->
  it 'counts jobs', ->
    worker = new FWF.Worker
    job1 = new Backbone.Model
    job2 = new Backbone.Model
    worker.set job: job1
    expect(worker.completions).toBe 0
    worker.set job: job2
    expect(worker.completions).toBe 1
    worker.set job: null
    expect(worker.completions).toBe 2
