{Emitter, CompositeDisposable} = require 'atom'
{$, View} = require 'atom-space-pen-views'

module.exports =
class SimulatorView  extends View
  @content: ->
    @div class: "simulator-view", tabindex: -1, =>
      @div class: "simulator-container", =>
        @canvas class: "canvas", width: "640px", height: "480px"

  initialize: (@simulator) ->
    console.log @simulator
    @emitter = new Emitter

  attached: ->
    @disposables = new CompositeDisposable

    #@disposables.add @simulator.onDidChange => @updateImageURI()
    @disposables.add atom.commands.add @element,
      'simulator-view:toggle': => @toggle()
      'simulator-view:reset': => @reset()
      'simulator-view:next': => @next()

  next: ->
    console.log "next"
    @simulator.next()

  toggle: ->
    @simulator.switchMode()

  reset: ->
    @simulator.reset()

  # Retrieves this view's pane.
  #
  # Returns a {Pane}.
  getPane: ->
    @parents('.pane')[0]
