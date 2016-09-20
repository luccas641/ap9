path = require 'path'
fs = require 'fs-plus'
Mnemonics = require './mnemonics'
PIT = require './pit'
Video = require './video
'
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
    @emitter = new Emitter
    @pit = new PIT
    @vid = new Video
    @file = new File(filePath)
    @uri = "file:#" + encodeURI(filePath.replace(/\\/g, '/')).replace(/#/g, '%23').replace(/\?/g, '%3F')
    @subscriptions = new CompositeDisposable()
    @automatic = false
    @reset()

  reset: ->
    @pit.clear()
    @vid.reset()
    @mem = []
    @file.read().then (content) =>
      @loadMif content

    @pc = 0
    @ir = 0
    @sp = 0x7FFC
    @auxpc = 0
    @pc2 = 0

    @setPC 0
    @setIR 0
    @setSP 0x7FFC
    @fr = [0, 0, 0, 0, 0 , 0, 0, 0, 0, 0, 0, 0, 0 , 0, 0, 0]
    @c0 = [0, 0, 0, 0, 0 , 0, 0, 0, 0, 0, 0, 0, 0 , 0, 0, 0]
    @irq = [0, 0, 0, 0, 0 , 0, 0, 0, 0, 0, 0, 0, 0 , 0, 0, 0]
    @reg = [0, 0, 0, 0, 0 , 0, 0, 0]

    #----Clock----
    @clock_count=0
    @clock_t=400
    @clock=100000
    @clock_interval
    undefined

  setView: (v) ->
    @view = v

  switchMode: ->
    if @automatic == false
      console.log  "automatico"
      @automatic=true
      @process()
      @emitter.emit 'status-change', "Manual"
    else
      console.log  "para automatico"
      @stop()
      @emitter.emit 'status-change', "Automatico"
    undefined

  next: =>
    @process()
    undefined

  pega_pedaco: (@ir, a, b) ->
    ((ir &  ( ((1 << (a+1)) - 1) )  ) >> b)

  process: ->
    if @automatic
      @automaticProcess()
    else
      @run() # executa soh uma vez
      @updateRegisters()
    undefined

  automaticProcess: ->
    @start = new Date()
    @clock_count=1000
    @interval=setInterval( =>
      @multiplicadorClock()
    , 1)
    @clock_interval=setInterval(=>
      @corrigeClock()
      @view.updateVew();
    , 1000)

  corrigeClock: ->
    atual = @clock_count
    @clock_t=@clock_t*@clock/@clock_count
    @clock_t=10000 if @clock_t>10000
    @clock_t=1 if @clock_t<1
    if atual>1000000
      atual = parseInt(atual/1000000) + " mhz"
    else if(atual>1000)
      atual = parseInt(atual/1000) + " khz"
    else
      atual = parseInt(atual)+" hz"

    @emitter.emit 'clock-change', atual
    console.log atual
    @clock_count=0

  multiplicadorClock: ->
    for i in [0..@clock_t]
      @run() if @automatic
    @clock_count+=@clock_t

  getBG: ->
    @vid.getBG()
    
  getSprites: ->
    @vid.getSprites()

  getOAM: ->
    @vid.getOAM();

  getPalette: ->
    @vid.getPalette();

  stop: ->
    @automatic=false
    @updateRegisters()
    window.clearInterval(@interval)
    window.clearInterval(@clock_interval)

  setRegisters: ->
    @reg[0] = @view.r0.getModel().getText()
    @reg[1] = @view.r0.getModel().getText()
    @reg[2] = @view.r0.getModel().getText()
    @reg[3] = @view.r0.getModel().getText()
    @reg[4] = @view.r0.getModel().getText()
    @reg[5] = @view.r0.getModel().getText()
    @reg[6] = @view.r0.getModel().getText()
    @reg[7] = @view.r0.getModel().getText()

  updateRegisters: ->
    @view.r0.getModel().setText @reg[0].toString()
    @view.r0.getModel().setText @reg[0].toString 16 if @hex
    @view.r1.getModel().setText @reg[1].toString()
    @view.r1.getModel().setText @reg[1].toString 16 if @hex
    @view.r2.getModel().setText @reg[2].toString()
    @view.r2.getModel().setText @reg[2].toString 16 if @hex
    @view.r3.getModel().setText @reg[3].toString()
    @view.r3.getModel().setText @reg[3].toString 16 if @hex
    @view.r4.getModel().setText @reg[4].toString()
    @view.r4.getModel().setText @reg[4].toString 16 if @hex
    @view.r5.getModel().setText @reg[5].toString()
    @view.r5.getModel().setText @reg[5].toString 16 if @hex
    @view.r6.getModel().setText @reg[6].toString()
    @view.r6.getModel().setText @reg[6].toString 16 if @hex
    @view.r7.getModel().setText @reg[7].toString()
    @view.r7.getModel().setText @reg[7].toString 16 if @hex

    @view.fr.getModel().setText @fr.toString().replace(/,/g, "")
    @view.fr.getModel().setText @fr.toString(16).replace(/,/g, "") if @hex

    @view.pc.getModel().setText @pc.toString()
    @view.pc.getModel().setText @pc.toString 16 if @hex

    @view.ir.getModel().setText @ir.toString()
    @view.ir.getModel().setText @ir.toString 16 if @hex

    @view.c0.getModel().setText @c0.toString().replace(/,/g, "")
    @view.c0.getModel().setText @c0.toString(16).replace(/,/g, "") if @hex

    @view.irq.getModel().setText @irq.toString().replace(/,/g, "")
    @view.irq.getModel().setText @irq.toString(16).replace(/,/g, "") if @hex

    @view.sp.getModel().setText @sp.toString()
    @view.sp.getModel().setText @sp.toString 16 if @hex

  getKey: ->
    @key = 255
    if(@key>=65 && @key <=90)
      @key+=32
    return @key

  setKey: (k)->
    @key = k

  setPC: (value) =>
    @pc = value%0x10000 if value >=0
    #@reg.update@pc()
    undefined

  setIR: (value) =>
    @ir = value%0x10000 if value >=0
    #@reg.updateIR()
    undefined

  setSP: (value) =>
    @sp = value%0x10000 if value >=0
    #@reg.update@sp()
    undefined

  setFR: (n, value) =>
    @fr[n] = value if value == 0 or value == 1
    #@reg.update@fr()
    undefined

  run: ->
    if(opcode != Mnemonics.RTS)
      irq = false;
      #Ciclo de interrupcao
      for i in [0..6]
        if(@irq[i])
          irq = true;
          break;
    if @irq and not @c0[1] and @c0[0]
      @c0[1] = 1;
      @mem[@sp] = @pc;
      @sp--;

      #Executa interrupcao
      if @irq[0]
          pc = @mem[0x7ff0];
          @irq[0] = 0;
      else if(@irq[1])
          pc = @mem[0x7ff1];
          @irq[1] = 0;
      else if(@irq[2])
          pc = @mem[0x7ff2];
          @irq[2] = 0;
      else if(@irq[3])
          pc = @mem[0x7ff3];
          @irq[3] = 0;
      else if(@irq[4])
          pc = @mem[0x7ff4];
          @irq[4] = 0;
      else if(@irq[5])
          pc = @mem[0x7ff5];
          @irq[5] = 0;
      else if(@irq[6])
          pc = @mem[0x7ff6];
          @irq[6] = 0;
      else if(@irq[7])
          pc = @mem[0x7ff7];
          @irq[7] = 0;
      else if(@irq[8])
          pc = @mem[0x7ff8];
          @irq[8] = 0;
      else if(@irq[9])
          pc = @mem[0x7ff9];
          @irq[9] = 0;
      else if(@irq[10])
          pc = @mem[0x7ffa];
          @irq[10] = 0;
      else if(@irq[11])
          pc = @mem[0x7ffb];
          @irq[11] = 0;
      else if(@irq[12])
          pc = @mem[0x7ffc];
          @irq[12] = 0;
      else if(@irq[13])
          pc = @mem[0x7ffd];
          @irq[13] = 0;
      else if(@irq[14])
          pc = @mem[0x7ffe];
          @irq[14] = 0;
      else if(@irq[15])
          pc = @mem[0x7fff];
          @irq[15] = 0;

    # ----- Ciclo de Busca: --------
    @ir = @mem[@pc]

    if @pc > 32767
      @stop()
      alert "ERRO: Ultrapassou limite da memoria, coloque um jmp no fim do código\n"
      return

    @pc++
    # ----------- -- ---------------

    # ------ Ciclo de Executa: ------
    rx = @pega_pedaco(@ir,9,7)
    ry = @pega_pedaco(@ir,6,4)
    rz = @pega_pedaco(@ir,3,1)
    # ------------- -- --------------

    # when .das instrucoes
    opcode = @pega_pedaco(@ir,15,10)
    switch opcode
      when Mnemonics.INCHAR
        if @reg[ry] == 0x900 #keyboard
          key = getKey();#getch();
          @reg[rx] = pega_pedaco(key,7,0);
        else if @reg[ry] >= 0x990 && @reg[ry] < 0x994 #PIT
          @pit.get(ry%4)
        else
          console.log "Erro: Voce tentou usar uma porta nao implementada ", @reg[ry]

      when Mnemonics.OUTCHAR
        if(@reg[ry] == 0) #video ADDR BG
          @vid.setAddrBG(@reg[rx]);
        else if(@reg[ry] == 1) #video BG
          @vid.addBG(@reg[rx]);
        else if(@reg[ry] == 2) #video ADDR OAM
          @vid.setAddrOAM(@reg[rx]);
        else if(@reg[ry] == 3) #Vdeo OAM
          @vid.addObject(@reg[rx]);
        else if(@reg[ry] == 4) #video ADDR SPRITE
          @vid.setAddrSprite(@reg[rx]);
        else if(@reg[ry] == 5) #video SPRITE
          @vid.addSprite(@reg[rx]);
        else if(@reg[ry] == 6) #video ADDR PALETTE
          @vid.setAddrPalette(@reg[rx]);
        else if(@reg[ry] == 7) #video PALETTE
          @vid.addPalette(@reg[rx]);
        else if(@reg[ry] >= 0x901 && @reg[ry] <= 0x902) #com1

        else if(@reg[ry] >= 0x990 && @reg[ry] < 0x994)#PIT
          @pit.set(ry%4, rx)
        else
          console.log "Erro: Voce tentou usar uma porta não implementada ", @reg[ry]

      when Mnemonics.EI
        switch @pega_pedaco(@ir,0,0)
          when 0
            @c0[0] = 0
          else
            @c0[0] = 1

      when Mnemonics.MOV
        switch @pega_pedaco(@ir,1,0)
          when 0
            @reg[rx] = @reg[ry]
          when 1
            @reg[rx] = @sp
          else
            @sp = @reg[rx]

      when Mnemonics.STORE
        @mem[@mem[@pc]] = @reg[rx]
        @pc++

      when Mnemonics.STOREINDEX
        @mem[@reg[rx]] = @reg[ry]

      when Mnemonics.LOAD
        @reg[rx] = @mem[@mem[@pc]]
        @pc++

      when Mnemonics.LOADIMED
        @reg[rx] = @mem[@pc]
        @pc++
      when Mnemonics.LOADINDEX
        @reg[rx] = @mem[@reg[ry]]

      when Mnemonics.LAND
        @reg[rx] = @reg[ry] & @reg[rz]
        @fr[3] = 0
        if @reg[rx] == 0
            @fr[3] = 1

      when Mnemonics.LOR
        @reg[rx] = @reg[ry] | @reg[rz]
        @fr[3] = 0 # -- @fr = <...|zero|equal|lesser|greater>
        if @reg[rx] == 0
            @fr[3] = 1

      when Mnemonics.LXOR
        @reg[rx] = @reg[ry] ^ @reg[rz]
        @fr[3] = 0 # -- @fr = <...|zero|equal|lesser|greater>
        if @reg[rx] == 0
            @fr[3] = 1

      when Mnemonics.LNOT
        @reg[rx] =  ~(@reg[ry])
        @fr[3] = 0 # -- @fr = <...|zero|equal|lesser|greater>
        if(@reg[rx] == 0)
            @fr[3] = 1

      when Mnemonics.CMP

        if (@reg[rx] > @reg[ry])
          @fr[2] = 0 # @fr = <...|zero|equal|lesser|greater>
          @fr[1] = 0
          @fr[0] = 1

        else if (@reg[rx] < @reg[ry])
          @fr[2] = 0 # @fr = <...|zero|equal|lesser|greater>
          @fr[1] = 1
          @fr[0] = 0

        else # @reg[rx] == @reg[ry]
          @fr[2] = 1 # @fr = <...|zero|equal|lesser|greater>
          @fr[1] = 0
          @fr[0] = 0

      when Mnemonics.JMP
        la = @pega_pedaco(@ir,9,6)
        if (la == 0) or (@fr[0]==1 and (la==7)) or ((@fr[2]==1 or @fr[0]==1) and (la==9)) or (@fr[1]==1 and (la==8))or ((@fr[2]==1 or @fr[1]==1) and (la==10)) or (@fr[2]==1 and (la==1)) or (@fr[2]==0 and (la==2)) or (@fr[3]==1 and (la==3)) or (@fr[3]==0 and (la==4)) or (@fr[4]==1 and (la==5)) or (@fr[4]==0 and (la==6)) or (@fr[5]==1 and (la==11)) or (@fr[5]==0 and (la==12)) or (@fr[6]==1 and (la==14)) or (@fr[9]==1 and (la==13))
          @pc = @mem[@pc]
        else
          @pc++
      when Mnemonics.PUSH
        if(!@pega_pedaco(@ir,6,6)) # @registrador
          @mem[@sp] = @reg[rx]
        else  # @fr
          temp = 0
          temp = temp + parseInt((@fr[i] * (Math.pow(2.0,i))))
          @mem[@sp] = temp

        @sp--

      when Mnemonics.POP
        @sp++
        if(!@pega_pedaco(@ir,6,6))  # @registrador
            @reg[rx] = @mem[@sp]
        else # @fr
          @fr[i] = @pega_pedaco(@mem[@sp],i,i) for i in [0..16]

      when Mnemonics.CALL
        la = @pega_pedaco(@ir,9,6)

        if (la == 0) or (@fr[0]==1 and (la==7)) or ((@fr[2]==1 or @fr[0]==1) and (la==9)) or (@fr[1]==1 and (la==8))or ((@fr[2]==1 or @fr[1]==1) and (la==10)) or (@fr[2]==1 and (la==1)) or (@fr[2]==0 and (la==2)) or (@fr[3]==1 and (la==3)) or (@fr[3]==0 and (la==4)) or (@fr[4]==1 and (la==5)) or (@fr[4]==0 and (la==6)) or (@fr[5]==1 and (la==11)) or (@fr[5]==0 and (la==12)) or (@fr[6]==1 and (la==14)) or (@fr[9]==1 and (la==13))
          @mem[@sp] = @pc
          @sp--
          @pc = @mem[@pc]
        else
          @pc++

      when Mnemonics.RTS
        @sp++
        @pc = @mem[@sp]
        @pc++

      when Mnemonics.ADD
        @reg[rx] = @reg[ry] + @reg[rz] # Soma sem Carry

        if @pega_pedaco(@ir,0,0)   # Soma com Carry
          @reg[rx] += @fr[4]

          @fr[3] = 0                   # -- @fr = <...|zero|equal|lesser|greater>
          @fr[4] = 0

        if !@reg[rx] # Se resultado = 0, seta o Flag de Zero
          @fr[3] = 1
        else
          if @reg[rx] > 0xffff
            @fr[4] = 1  # Deu Carry
            @reg[rx] = @reg[rx] - 0xffff

      when Mnemonics.SUB
        @reg[rx] = @reg[ry] - @reg[rz] # Subtracao sem Carry

        if @pega_pedaco(@ir,0,0)==1  # Subtracao com Carry
          @reg[rx] += @fr[4]

        @fr[3] = 0 # -- @fr = <...|zero|equal|lesser|greater>
        @fr[9] = 0

        if not @reg[rx] # Se resultado = 0, seta o Flag de Zero
            @fr[3] = 1
        else
          if @reg[rx] < 0x0000
            @fr[9] = 1  # Resultado e' Negativo
            @reg[rx] = 0

      when Mnemonics.MULT
        @reg[rx] = @reg[ry] * @reg[rz] # MULT sem Carry

        if(@pega_pedaco(@ir,0,0)==1)  # MULT com Carry
          @reg[rx] += @fr[4]

          @fr[3] = 0 # -- @fr = <...|zero|equal|lesser|greater>
          @fr[5] = 0

        if(!@reg[rx])
          @fr[3] = 1  # Se resultado = 0, seta o Flag de Zero
        else
          if(@reg[rx] > 0xffff)
            @fr[5] = 1  # Arithmetic Overflow

      when Mnemonics.DIV
        if !@reg[rz]
          @fr[6] = 1  # Arithmetic Overflow
          @reg[rx] = 0
          @fr[3] = 1  # Se resultado = 0, seta o Flag de Zero
        else
          @fr[6] = 0

          @reg[rx] = parseInt(@reg[ry] / @reg[rz]) # DIV sem Carry
          if @pega_pedaco(@ir,0,0)==1   # DIV com Carry
            @reg[rx] += @fr[4]

          @fr[3] = 0 # -- @fr = <...|zero|equal|lesser|greater>
          if !@reg[rx]
            @fr[3] = 1  # Se resultado = 0, seta o Flag de Zero

      when Mnemonics.LMOD
        @reg[rx] = @reg[ry] % @reg[rz]

        @fr[3] = 0 # -- @fr = <...|zero|equal|lesser|greater

        if !@reg[rx]
          @fr[3] = 1  # Se resultado = 0, seta o Flag de Zero

      when Mnemonics.INC
        @reg[rx]++                  # Inc Rx
        if @pega_pedaco(@ir,6,6)!=0 # Dec Rx
          @reg[rx] = @reg[rx] - 2

        @fr[3] = 0 # -- @fr = <...|zero|equal|lesser|greater>
        if(!@reg[rx])
          @fr[3] = 1  # Se resultado = 0, seta o Flag de Zero

      when Mnemonics.SHIFT
        @fr[3] = 0 # -- @fr = <...|zero|equal|lesser|greater>

        if(!@reg[rx])
          @fr[3] = 1  # Se resultado = 0, seta o Flag de Zero

        switch @pega_pedaco(@ir,6,4)
          when 0
            @reg[rx] = @reg[rx] << @pega_pedaco(@ir,3,0)
          when 1
            @reg[rx] = ~((~(@reg[rx]) << @pega_pedaco(@ir,3,0)))
          when 2
            @reg[rx] = @reg[rx] >> @pega_pedaco(@ir,3,0)
          when 3
            @reg[rx] = ~((~(@reg[rx]) >> @pega_pedaco(@ir,3,0)))

            if(@pega_pedaco(@ir,6,5)==2) # ROTATE LEFT
              @reg[rx] = _rotl(@reg[rx],@pega_pedaco(@ir,3,0))
            else #TODO verificar
              @reg[rx] = _rotr(@reg[rx],@pega_pedaco(@ir,3,0))

      when Mnemonics.SETC
        @fr[4] = @pega_pedaco(@ir,9,9)

      when Mnemonics.HALT
        @stop()

      when Mnemonics.BREAKP
        @stop()

    @reg[rx]=@reg[rx]&0xffff

    # ----- Ciclo de Busca: --------
    ir2 = @mem[@pc]
    @pc2 = @pc + 1
    # ----------- -- ---------------

    # when .das instrucoes
    opcode = @pega_pedaco(ir2,15,10)

    switch(opcode)
      when Mnemonics.JMP
        la = @pega_pedaco(ir2,9,6)

        if (la == 0) or (@fr[0]==1 and (la==7)) or ((@fr[2]==1 or @fr[0]==1) and (la==9)) or (@fr[1]==1 and (la==8))or ((@fr[2]==1 or @fr[1]==1) and (la==10)) or (@fr[2]==1 and (la==1)) or (@fr[2]==0 and (la==2)) or (@fr[3]==1 and (la==3)) or (@fr[3]==0 and (la==4)) or (@fr[4]==1 and (la==5)) or (@fr[4]==0 and (la==6)) or (@fr[5]==1 and (la==11)) or (@fr[5]==0 and (la==12)) or (@fr[6]==1 and (la==14)) or (@fr[9]==1 and (la==13))
            @pc2 = @mem[@pc2]
          else
            @pc2++

      when Mnemonics.CALL
        la = @pega_pedaco(ir2,9,6)

        if (la == 0) or (@fr[0]==1 and (la==7)) or ((@fr[2]==1 or @fr[0]==1) and (la==9)) or (@fr[1]==1 and (la==8))or ((@fr[2]==1 or @fr[1]==1) and (la==10)) or (@fr[2]==1 and (la==1)) or (@fr[2]==0 and (la==2)) or (@fr[3]==1 and (la==3)) or (@fr[3]==0 and (la==4)) or (@fr[4]==1 and (la==5)) or (@fr[4]==0 and (la==6)) or (@fr[5]==1 and (la==11)) or (@fr[5]==0 and (la==12)) or (@fr[6]==1 and (la==14)) or (@fr[9]==1 and (la==13))
            @pc2 = @mem[@pc2]
          else
            @pc2++

      when Mnemonics.RTS
        @pc2 = @mem[@sp+1]
        @pc2++

      when Mnemonics.LOADIMED
        @pc2++

      when Mnemonics.BREAKP
        @stop()
        #@notifyProcessamento()

      when Mnemonics.HALT
        @stop()
        #@notifyProcessamento()

  undefined

  serialize: ->
    {filePath: @getPath(), deserializer: @constructor.name}

  getViewClass: ->
    require './simulator-view'

  terminatePendingState: ->
    @emitter.emit 'did-terminate-pending-state' if @isEqual(atom.workspace.getActivePane().getPendingItem())

  onDidTerminatePendingState: (callback) ->
    @emitter.on 'did-terminate-pending-state', callback

  # @register a callback for when the source file changes
  onDidChange: (callback) ->
    changeSubscription = @file.onDidChange(callback)
    @subscriptions.add(changeSubscription)
    changeSubscription

  # @register a callback for whne the souce's title changes
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

  # Register a callback for when the image file changes
  onDidChange: (callback) ->
    changeSubscription = @file.onDidChange(callback)
    @subscriptions.add(changeSubscription)
    changeSubscription

  # Register a callback for whne the image's title changes
  onDidChangeTitle: (callback) ->
    renameSubscription = @file.onDidRename(callback)
    @subscriptions.add(renameSubscription)
    renameSubscription

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
  # * `callback` {-> } to be called when the editor is destroyed.
  #
  # Returns a {Di@sposable} on which `.di@spose()` can be called to unsubscribe.
  onDidDestroy: (callback) ->
    @emitter.on 'did-destroy', callback

  loadMif: (cpuram) ->
    line = cpuram.split("\n")
    @mem[i-6] = parseInt(line[i].split(":")[1],2) for i in [6..32775]

  loadCharmap: (charmap)->
    maps = charmap.split("\n")

    chars[i] = new Array() for i in [0..1024]

    for map in maps
      if map.search("^(\t[0-9]+(?:\[0-9]*)?.*:.*[0-9]+(?:\[0-9]*)?)") != -1
        mapTok = map.match(/[0-9]+(?:\[0-9]*)?/g)
        pos = parseInt(mapTok[0])
        value = mapTok[1]
        chars[pos][j] = parseInt(value.charAt(j)) for j in [0..8]
      else if map.search("^(\t\[[0-9]+(?:\[0-9]*)?..[0-9]+(?:\[0-9]*)?].*:.*[0-9]+(?:\[0-9]*)?)")!=-1
        mapTok = map.match(/[0-9]+(?:\[0-9]*)?/g)
        pos1 = parseInt(mapTok[0])
        pos2 = parseInt(mapTok[1])
        value = mapTok[2]
