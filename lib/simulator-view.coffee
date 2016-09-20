{Emitter} = require 'atom'
SubAtom = require('sub-atom')
{$, View, TextEditorView} = require 'atom-space-pen-views'

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
        @input class: 'inline-block range',  type: "range", name: "clockSel", id: "clockSel" ,min: "1", max: "1000000", value: "100000"
      @div class: "simulator-container", =>
        @div class: "canvas-container", =>
          @canvas class: "canvas", width: "640px", height: "480px", focusable="True", outlet: "canvasBack"
          @canvas class: "canvas", width: "640px", height: "480px", focusable="True", outlet: "canvasFront"
        @div class: "simulator-code", =>
          @p "none yet"

  initialize: (@simulator) ->
    @emitter = @simulator.emitter

  attached: ->
    @disposables = new SubAtom
    @simulator.setView this
    @simulator.updateRegisters()

    @disposables.add @element, 'keydown', (evt) =>
      @simulator.setKey(evt.which)

    @disposables.add ".reg", 'keydown', (evt) =>
      @simulator.setRegisters();

    @disposables.add @nextBtn, 'click', =>
      @next()

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

    @ctxBg=@canvasBack[0].getContext("2d")
    @ctxFr=@canvasFront[0].getContext("2d")

    @canvasData = [@ctxBg.getImageData(0, 0, 640, 480), @ctxFr.getImageData(0, 0, 640, 480)]

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

  updateVew: () ->
    bg = @simulator.getBG()
    @drawOnScreen 0, bg[i].c, bg[i].p, 8*(i%40), 8*(i/40), bg[i].v, bg[i].h for i in [0..1200]
    @updateCanvas(0)

    oam = @simulator.getOAM()
    @drawOnScreen 1, oam[i].c, oam[i].p, oam[i].x, oam[i].y, oam[i].v, oam[i].h for i in [0..128]
    @updateCanvas(1)
  drawOnScreen: (canvas, sprite, palette, x, y, v, h) ->
     sprites = @simulator.getSprites();
     for i in [0..8]
        for j in [0..8]
          color = ((sprites[(sprite<<3)+i])>>j&1) + ((sprites[(sprite<<3)+i]>>(j+8))&1)*2
          indexX = (8-j+x)*2
          indexY = (i+y)*2
          if v && !h
            indexX = (j+x)*2
          else if h && !v
            indexY = (8-i+y)*2

          else if v && h
            indexX = (j+x)*2
            indexY = (8-i+y)*2

          @drawPixel canvas, indexX, indexY, palette, color

  # -------- Video --------
  drawPixel: (canvas, x, y, palette, color) ->

    if canvas==1 and color == 0
      A = 0
    else
      p = @simulator.getPalette()
      c = p[palette << 2 | color];
      B = c.blue/32.0
      G = c.green/32.0
      R = c.red/32.0
      A = 255

    for i in [x*2..x*2+2]
      for j in [y*2..y*2+2]
        index = (i + j * 640) * 4;

        @canvasData[canvas].data[index + 0] = R;
        @canvasData[canvas].data[index + 1] = G;
        @canvasData[canvas].data[index + 2] = B;
        @canvasData[canvas].data[index + 3] = A;

  updateCanvas: (canvas) ->
    if(canvas)
      @ctxFr.putImageData(@canvasData[canvas], 0, 0);
    else
      @ctxBg.putImageData(@canvasData[canvas], 0, 0);

  # Retrieves this view's pane.
  #
  # Returns a {Pane}.
  getPane: ->
    @parents('.pane')[0]
