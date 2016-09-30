path = require 'path'
fs = require 'fs-plus'
_ = require 'underscore-plus'
Simulator = require './simulator'
{Emitter, File, CompositeDisposable} = require 'atom'

simulatorView = null
baseURI = 'atom://ap9'
module.exports =
  activate: ->
    @statusViewAttached = false
    # Events subscribed to in atom's system can be easily cleaned up with a CompositeDisposable
    @disposables = new CompositeDisposable
    @disposables.add atom.workspace.addOpener(openURI)
    @disposables.add atom.workspace.onDidChangeActivePaneItem => @attachStatusView()

    # Register command that toggles this view
    @disposables.add atom.commands.add 'atom-workspace', 'test:openSimulator': => @openSimulator()

  consumeStatusBar: (@statusBar) -> @attachStatusView()

  attachStatusView: ->
    return if @statusViewAttached
    return unless @statusBar?
    return unless atom.workspace.getActivePaneItem() instanceof Simulator

    SimulatorStatusView = require './simulator-status-view'
    @simulatorStatusView = new SimulatorStatusView(@statusBar)
    @simulatorStatusView.attach()

    @statusViewAttached = true

  deactivate: ->
    @disposables.dispose()

  openSimulator: ->
    atom.workspace.open baseURI

# Files with these extensions will be opened on simulator
openURI = (uriToOpen) ->
  uriExtension = path.extname(uriToOpen).toLowerCase()
  if _.include(['.mif'], uriExtension)
    simulatorView ?= new Simulator uriToOpen
