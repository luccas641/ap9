path = require 'path'
fs = require 'fs-plus'
{Emitter, File, CompositeDisposable} = require 'atom'

# Model for an Simulator view
module.exports =
class Simulator
  atom.deserializers.add(this)

  @deserialize: ({filePath}) ->
    if fs.isFileSync(filePath)
      new Simulator(filePath)
    else
      console.warn "Could not deserialize simulator for path '#{filePath}' because that file no longer exists"

  constructor: (filePath) ->
    @file = new File(filePath)
    @uri = "file://" + encodeURI(filePath.replace(/\\/g, '/')).replace(/#/g, '%23').replace(/\?/g, '%3F')
    @subscriptions = new CompositeDisposable()
    @emitter = new Emitter


  serialize: ->
    {filePath: @getPath(), deserializer: @constructor.name}

  getViewClass: ->
    require './simulator-view'

  terminatePendingState: ->
    @emitter.emit 'did-terminate-pending-state' if this.isEqual(atom.workspace.getActivePane().getPendingItem())

  onDidTerminatePendingState: (callback) ->
    @emitter.on 'did-terminate-pending-state', callback

  # Register a callback for when the source file changes
  onDidChange: (callback) ->
    changeSubscription = @file.onDidChange(callback)
    @subscriptions.add(changeSubscription)
    changeSubscription

  # Register a callback for whne the souce's title changes
  onDidChangeTitle: (callback) ->
    renameSubscription = @file.onDidRename(callback)
    @subscriptions.add(renameSubscription)
    renameSubscription

  destroy: ->
    @subscriptions.dispose()

  # Retrieves the filename of the open file.
  #
  # This is `'untitled'` if the file is new and not saved to the disk.
  #
  # Returns a {String}.
  getTitle: ->
    if filePath = @getPath()
      path.basename(filePath)
    else
      'untitled'

  # Retrieves the URI of the souce.
  #
  # Returns a {String}.
  getURI: -> @uri

  # Retrieves the absolute path to the souce.
  #
  # Returns a {String} path.
  getPath: -> @file.getPath()

  # Compares two {Simulator}s to determine equality.
  #
  # Equality is based on the condition that the two URIs are the same.
  #
  # Returns a {Boolean}.
  isEqual: (other) ->
    other instanceof Simulator and @getURI() is other.getURI()

  # Essential: Invoke the given callback when the editor is destroyed.
  #
  # * `callback` {Function} to be called when the editor is destroyed.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidDestroy: (callback) ->
    @emitter.on 'did-destroy', callback

	loadCharmap: (charmap)->
  	maps = charmap.split("\n")

  	chars[i] = new Array() for i in [0..1024]

  	for map in maps
  		if map.search("^(\t[0-9]+(?:\[0-9]*)?.*:.*[0-9]+(?:\[0-9]*)?;)") != -1
  			mapTok = map.match(/[0-9]+(?:\[0-9]*)?/g)
  			pos = parseInt(mapTok[0])
  			value = mapTok[1]
  			chars[pos][j] = parseInt(value.charAt(j)) for j in [0..8]
  		else if map.search("^(\t\[[0-9]+(?:\[0-9]*)?..[0-9]+(?:\[0-9]*)?].*:.*[0-9]+(?:\[0-9]*)?;)")!=-1
  			mapTok = map.match(/[0-9]+(?:\[0-9]*)?/g)
  			pos1 = parseInt(mapTok[0])
  			pos2 = parseInt(mapTok[1])
  			value = mapTok[2]
        for k in [pos1..pos2]
          for j in [0..8]
            chars[k][j] = parseInt(value.charAt(j))
