{Emitter} = require 'atom'
SubAtom = require('sub-atom')
{$, View, TextEditorView} = require 'atom-space-pen-views'
q = require('q');

module.exports =
class SimulatorView  extends View
  @content: ->
    @div class: "simulator-view", tabindex: -1, =>
      @div class: "simulator-panel block", =>
        @label "R0"
        @subview "r0", new TextEditorView(mini: true, attributes: {id: "r0", outlet: "r0", type: "string", class: "inline-block reg"})
        @label "R1"
        @subview "r1", new TextEditorView(mini: true, attributes: {id: "r1", outlet: "r1", type: "string", class: "inline-block reg"})
        @label "R2"
        @subview "r2", new TextEditorView(mini: true, attributes: {id: "r2", outlet: "r2", type: "string", class: "inline-block reg"})
        @label "R3"
        @subview "r3", new TextEditorView(mini: true, attributes: {id: "r3", outlet: "r3", type: "string", class: "inline-block reg"})
        @label "R4"
        @subview "r4", new TextEditorView(mini: true, attributes: {id: "r4", outlet: "r4", type: "string", class: "inline-block reg"})
        @label "R5"
        @subview "r5", new TextEditorView(mini: true, attributes: {id: "r5", outlet: "r5", type: "string", class: "inline-block reg"})
        @label "R6"
        @subview "r6", new TextEditorView(mini: true, attributes: {id: "r6", outlet: "r6", type: "string", class: "inline-block reg"})
        @label "R7"
        @subview "r7", new TextEditorView(mini: true, attributes: {id: "r7", outlet: "r7", type: "string", class: "inline-block reg"})
        @div class: 'inline-block btn-group', =>
          @button class: 'inline-block btn', outlet: 'nextBtn', type: "button", id: "buttonNext",  "Próximo"
          @button class: 'inline-block btn', outlet: 'toggleBtn', type: "button", id: "buttonAutomatico",  "Automatico"
          @button class: 'inline-block btn', outlet: 'resetBtn', type: "button", id: "buttonReset",  "Resetar"
      @div class: "simulator-panel block", =>
        @label id: "labelPC", "PC"
        @subview "pc", new TextEditorView(mini: true, attributes: {id: "pc", outlet: "pc", type: "string", class: "inline-block reg"})
        @label id: "labelIR", "IR"
        @subview "ir", new TextEditorView(mini: true, attributes: {id: "ir", outlet: "ir", type: "string", class: "inline-block reg"})
        @label id: "labelSP", "SP"
        @subview "sp", new TextEditorView(mini: true, attributes: {id: "sp", outlet: "sp", type: "string", class: "inline-block reg"})
        @label id: "labelFR", "FR"
        @subview "fr", new TextEditorView(mini: true, attributes: {id: "fr", outlet: "fr", type: "string", class: "inline-block reg big"})
        @label id: "labelC0", "C0"
        @subview "c0", new TextEditorView(mini: true, attributes: {id: "c0", outlet: "c0", type: "string", class: "inline-block reg big"})
        @label id: "labelIRQ", "IRQ"
        @subview "irq", new TextEditorView(mini: true, attributes: {id: "irq", outlet: "irq", type: "string", class: "inline-block reg big"})
      @div class: "simulator-container", =>
        @div class: "canvas-container", outlet: "container", =>
          @canvas class: "canvas", focusable="True", outlet: "canvas"
          @canvas class: "canvas", focusable="True", outlet: "canvasOam"

  initialize: (@simulator) ->
    @emitter = @simulator.emitter
    @line = 0

  attached: ->
    @disposables = new SubAtom
    @simulator.setView this
    @simulator.updateRegisters()

    @disposables.add @element, 'keydown', (evt) =>
      @simulator.pressKey(evt.which)

    @disposables.add @element, 'keyup', (evt) =>
      @simulator.releaseKey(evt.which)

    @disposables.add ".reg", 'keydown', (evt) =>
      @simulator.setRegisters();

    @disposables.add @nextBtn, 'click', =>
      @next()

    @disposables.add @resetBtn, 'click', =>
      @reset()

    @disposables.add @toggleBtn, 'click', =>
      @toggle()

    @onStatusChange (status) =>
      console.log('onchange')
      @toggleBtn.html(status)


    #@disposables.add @simulator.onDidChange => @updateImageURI()
    @disposables.add atom.commands.add @element,
      'simulator-view:toggle': => @toggle()
      'simulator-view:reset': => @reset()
      'simulator-view:next': => @next()
      'simulator-view:fullscreen': => @toggleFullScreen()

    @ctx=@canvas[0].getContext("2d")
    @ctxOam=@canvasOam[0].getContext("2d")
    @fixCanvasForPPI(320,240)
    @ctx.imageSmoothingEnabled= false
    @ctx.webkitImageSmoothingEnabled = false;
    @ctx.mozImageSmoothingEnabled = false;
    @ctxOam.imageSmoothingEnabled= false
    @ctxOam.webkitImageSmoothingEnabled = false;
    @ctxOam.mozImageSmoothingEnabled = false;

    @canvasData = @ctx.getImageData(0, 0, 320, 240)
    @canvasDataOam = @ctxOam.getImageData(0, 0, 320, 240)
    @fullscreen = false;
  toggleFullScreen: () ->
    if @fullscreen
      @fullscreen = false;
      @container.removeClass "full"
      @container[0].webkitCancelFullScreen()
    else
      @fullscreen = true;
      @container.addClass "full"
      @container[0].webkitRequestFullScreen()
  fixCanvasForPPI: (width, height) ->

      width = parseInt(width);
      height = parseInt(height);

      #finally query the various pixel ratios
      devicePixelRatio = window.devicePixelRatio || 1;
      backingStoreRatio = @ctx.webkitBackingStorePixelRatio ||
                          @ctx.mozBackingStorePixelRatio ||
                          @ctx.msBackingStorePixelRatio ||
                          @ctx.oBackingStorePixelRatio ||
                          @ctx.backingStorePixelRatio || 1;
      ratio = devicePixelRatio / backingStoreRatio;
      #ensure we have a value set for auto.
      #// If auto is set to false then we
      #// will simply not upscale the canvas
      #// and the default behaviour will be maintained
      #// upscale the canvas if the two ratios don't match
      if (devicePixelRatio != backingStoreRatio)

          @canvas.attr({
              'width': width * ratio,
              'height': height * ratio
          });

          @canvas.css({
              'width': width + 'px',
              'height': height + 'px'
          });

          #// now scale the context to counter
          #// the fact that we've manually scaled
          #// our canvas element
          @ctx.scale(ratio, ratio);

          @canvasOam.attr({
              'width': width * ratio,
              'height': height * ratio
          });

          @canvasOam.css({
              'width': width + 'px',
              'height': height + 'px'
          });

          #// now scale the context to counter
          #// the fact that we've manually scaled
          #// our canvas element
          @ctxOam.scale(ratio, ratio);

      #// No weird ppi so just resize canvas to fit the tag
      else

          @canvas.attr({
              'width': width,
              'height': height
          });

          @canvas.css({
              'width': width + 'px',
              'height': height + 'px'
          });

          @canvasOam.attr({
              'width': width,
              'height': height
          });

          @canvasOam.css({
              'width': width + 'px',
              'height': height + 'px'
          });

  next: ->
    console.log "next"
    @simulator.next()

  toggle: ->
    @simulator.switchMode()

  reset: ->
    @simulator.reset()

  onStatusChange: (callback)->
    @emitter.on 'status-change', callback

  onDidLoad: (callback) ->
    @emitter.on 'did-load', callback

  updateView: () ->
    bg = @simulator.getBG()
    @drawOnScreen 0, bg[i].c, bg[i].p, 8*(i%40), 8*parseInt(i/40), bg[i].v, bg[i].h for i in [0..1199]

    oam = @simulator.getOAM()
    @drawOnScreen 1, oam[i].c, oam[i].p, oam[i].x, oam[i].y, oam[i].v, oam[i].h for i in [0..127]
    @updateCanvas()

  rasterizeView: () ->
    @rasterize_background_line @line
    @rasterize_sprites_line @line
    @line++
    if(@line==240)
      @updateCanvas()
      @line = 0

  rasterize_background_line: (line) ->
    bg = @simulator.getBG()
    sprites = @simulator.getSprites();
    row = parseInt line/8
    offset = line%8
    for k in [row*40..(row+1)*40-1]
      if bg[k].dirty or @simulator.isPalettesDirty()==false
        x = 8*(k%40)
        y = line
        sprite = bg[k].c
        palette = bg[k].p
        v = bg[k].v
        h = bg[k].h
        if !h
          i = offset
        else
          i = 7 - offset
        sprite = sprites[(sprite<<3)+i];
        for j in [0..7]
          indexX = (7-j+x)
          if v
            indexX = (j+x)
          @drawPixel 0, indexX, line, palette, sprite[j]
        bg[k].dirty = false if offset == 7


  rasterize_sprites_line: (line) ->
    oam = @simulator.getOAM()
    sprites = @simulator.getSprites();
    count = 0
    offset = line%8
    for k in [0..127]
      if count==8 then break;
      if line>=oam[k].y && line<oam[k].y+8 && (oam[k].dirty or @simulator.isPalettesDirty()==false)
        x = oam[k].x
        y = oam[k].y
        sprite = oam[k].c
        palette = oam[k].p
        v = oam[k].v
        h = oam[k].h
        if !h
          i = line - y
        else
          i = 7 - line + y
        sprite = sprites[(sprite<<3)+i];
        for j in [0..7]
          indexX = (7-j+x)
          if v
            indexX = (j+x)

          @drawPixel 1, indexX, line, palette, sprite[j] if sprite[j]
        count++

    undefined

  drawOnScreen: (layer, sprite, palette, x, y, v, h) ->
     sprites = @simulator.getSprites();
     for i in [0..7]
        for j in [0..7]
          color = ((sprites[(sprite<<3)+i])>>j&1) + ((sprites[(sprite<<3)+i]>>(j+8))&1)*2
          indexX = (7-j+x)
          indexY = (i+y)
          if v && !h
            indexX = (j+x)
          else if h && !v
            indexY = (7-i+y)
          else if v && h
            indexX = (j+x)
            indexY = (7-i+y)
          if (layer==1 && color) or layer == 0
            @drawPixel layer, indexX, indexY, palette, color

  # -------- Video --------
  drawPixel: (layer, x, y, palette, color) ->
    p = @simulator.getPalette()
    if layer==0 and color==0
      A = 0
      B = 0
      G = 0
      R = 0
    else
      c = p[palette << 2 | color];
      B = c.blue*8
      G = c.green*8
      R = c.red*8
      A = 255
    index = (x + y * 320) * 4;
    if(layer==0)
      @canvasData.data[index + 0] = R;
      @canvasData.data[index + 1] = G;
      @canvasData.data[index + 2] = B;
      @canvasData.data[index + 3] = A;
    else
      @canvasDataOam.data[index + 0] = R;
      @canvasDataOam.data[index + 1] = G;
      @canvasDataOam.data[index + 2] = B;
      @canvasDataOam.data[index + 3] = A;

  updateCanvas: ()->
    thisLoop = new Date
    @fps = 1000 / (thisLoop - @lastLoop)
    @lastLoop = thisLoop
    @ctx.putImageData @canvasData, 0, 0
    @ctxOam.putImageData @canvasDataOam, 0, 0
    @canvasDataOam = @ctxOam.createImageData 320,240
    @simulator.setPalletesDirty false

  # Retrieves this view's pane.
  #
  # Returns a {Pane}.
  getPane: ->
    @parents('.pane')[0]
