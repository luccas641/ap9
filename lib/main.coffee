path = require 'path'
fs = require 'fs-plus'
_ = require 'underscore-plus'
Simulator = require './simulator'
{Emitter, File, CompositeDisposable} = require 'atom'

baseURI = 'atom://ap9'
module.exports =
  activate: ->
    # Events subscribed to in atom's system can be easily cleaned up with a CompositeDisposable
    @disposables = new CompositeDisposable
    @disposables.add atom.workspace.addOpener(openURI)

    # Register command that toggles this view
    @disposables.add atom.commands.add 'atom-workspace', 'test:openSimulator': => @openSimulator()


  deactivate: ->
    @disposables.dispose()

  openSimulator: ->
    atom.workspace.open(baseURI)

# Files with these extensions will be opened on simulator
openURI = (uriToOpen) ->
  uriExtension = path.extname(uriToOpen).toLowerCase()
  if _.include(['.mif'], uriExtension)
    new Simulator(uriToOpen)
