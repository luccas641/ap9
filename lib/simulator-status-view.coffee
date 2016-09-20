{$, View} = require 'atom-space-pen-views'
{CompositeDisposable, Emitter} = require 'atom'
Simulator = require './simulator'

module.exports =
class SimulatorStatusView extends View
  @content: ->
    @div class: 'status-simulator inline-block', =>
      @span class: 'status', outlet: 'simulatorStatus', 'Manual'
      @span class: 'clock', outlet: 'simulatorClock', '0 mhz'

  initialize: (@statusBar) ->
    @disposables = new CompositeDisposable
    @emitter = new Emitter
    @onClockChange (clock) =>
      @simulatorClock.val clock
    @onStatusChange (status) =>
      @simulatorStatus.val status

    @attach()

    @disposables.add atom.workspace.onDidChangeActivePaneItem => @updateStatusBar()

  attach: ->
    @statusBar.addLeftTile(item: this)

  attached: ->
    @updateStatusBar()

  onClockChange: (callback)->
    @emitter.on 'clock-change', callback

  onStatusChange: (callback)->
    @emitter.on 'status-change', callback

  updateStatusBar: ->
    editor = atom.workspace.getActivePaneItem()
    if editor instanceof Simulator
      @simulatorClock.show()
      @simulatorStatus.show()
    else
      @simulatorClock.hide()
      @simulatorStatus.hide()
