path = require 'path'
fs = require 'fs-plus'
Mnemonics = require './mnemonics'
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
    @uri = "file:#" + encodeURI(filePath.replace(/\\/g, '/')).replace(/#/g, '%23').replace(/\?/g, '%3F')
    @subscriptions = new CompositeDisposable()
    @emitter = new Emitter
    @reset()

  reset: ->
    @mem = []
    @file.read().then (content) =>
      @loadMif content

    @pc = 0
    @ir = 0
    @sp = 0x7FFC


    @setPC 0
    @setIR 0
    @setSP 0x7FFC
    @fr = [0, 0, 0, 0, 0 , 0, 0, 0, 0, 0, 0, 0, 0 , 0, 0, 0]
    @reg = [0, 0, 0, 0, 0 , 0, 0, 0]

    #----Clock----
    @clock_count=0
    @clock_t=400
    @clock=100000
    @clock_interval
    console.log "reset"
    undefined

  switchMode: ->
    if not @automatic
      @automatic=true
      @process()
      #document.getElementById("status").innerHTML="automatic"
      #document.getElementById("buttonautomatic").innerHTML="Manual"
    else
      @automatic=false
      #document.getElementById("status").innerHTML="Manual"
      #document.getElementById("clock").innerHTML=""
      @stop()
      #document.getElementById("buttonautomatic").innerHTML="automatic"
    undefined

  next: =>
    console.log "simulator next"
    @process
    undefined


  pega_pedaco: (ir, a, b) ->
    ((ir &  ( ((1 << (a+1)) - 1) )  ) >> b)

  process: ->
    if @automatic
      @automaticProcess()
    else
      @run() # executa soh uma vez
      #@updateAll()
    undefined

  automaticProcess: ->
    console.log "start automatic"
    @start = new Date()
    @clock_count=1000
    @interval=setInterval( =>
      @multiplicadorClock()
    , 1)
    @clock_interval=setInterval(=>
      @corrigeClock()
    , 1000)

  corrigeClock: ->
    console.log this
    @clock_t=@clock_t*@clock/@clock_count
    @clock_t=10000 if @clock_t>10000
    @clock_t=1 if @clock_t<1
    console.log "corrige", @clock_t
    #if atual>1000000
    #  document.getElementById("clock").innerHTML="Clock: "+parseInt(atual/1000000) + " mhz"
    #else if(atual>1000)
    #  document.getElementById("clock").innerHTML="Clock: "+parseInt(atual/1000) + " khz"
    #else
    #  document.getElementById("clock").innerHTML="Clock: "+parseInt(atual)+" hz"
    @clock_count=0

  multiplicadorClock: ->
    @run() for i in [0..@clock_t]
    @clock_count+=@clock_t

  stop: ->
    console.log "stop"
    window.clearInterval(@interval)
    window.clearInterval(@clock_interval)
    #@updateAll()

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
    # ----- Ciclo de Busca: --------
    ir = @mem[@pc]

    if @pc > 32767
      @automatic = false
      @stop()
      alert "ERRO: Ultrapassou limite da @memoria, coloque um jmp no fim do código\n"
      return

    @pc++
    # ----------- -- ---------------

    # ------ Ciclo de Executa: ------
    rx = @pega_pedaco(ir,9,7)
    ry = @pega_pedaco(ir,6,4)
    rz = @pega_pedaco(ir,3,1)
    # ------------- -- --------------

    # when .das instrucoes
    opcode = @pega_pedaco(ir,15,10)

    switch opcode
      when Mnemonics.MOV
        switch @pega_pedaco(ir,1,0)
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
        #console.log(@mem[@pc])
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
        la = @pega_pedaco(ir,9,6)
        if (la == 0) or (@fr[0]==1 and (la==7)) or ((@fr[2]==1 or @fr[0]==1) and (la==9)) or (@fr[1]==1 and (la==8))or ((@fr[2]==1 or @fr[1]==1) and (la==10)) or (@fr[2]==1 and (la==1)) or (@fr[2]==0 and (la==2)) or (@fr[3]==1 and (la==3)) or (@fr[3]==0 and (la==4)) or (@fr[4]==1 and (la==5)) or (@fr[4]==0 and (la==6)) or (@fr[5]==1 and (la==11)) or (@fr[5]==0 and (la==12)) or (@fr[6]==1 and (la==14)) or (@fr[9]==1 and (la==13))
          @pc = @mem[@pc]
        else
          @pc++
      when Mnemonics.PUSH
        if(!@pega_pedaco(ir,6,6)) # @registrador
          @mem[@sp] = @reg[rx]
        else  # @fr
          temp = 0
          temp = temp + parseInt((@fr[i] * (Math.pow(2.0,i))))
          @mem[@sp] = temp

        @sp--

      when Mnemonics.POP
        @sp++
        if(!@pega_pedaco(ir,6,6))  # @registrador
            @reg[rx] = @mem[@sp]
        else # @fr
          @fr[i] = @pega_pedaco(@mem[@sp],i,i) for i in [0..16]

      when Mnemonics.CALL
        la = @pega_pedaco(ir,9,6)

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

        if @pega_pedaco(ir,0,0)   # Soma com Carry
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

        if @pega_pedaco(ir,0,0)==1  # Subtracao com Carry
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

        if(@pega_pedaco(ir,0,0)==1)  # MULT com Carry
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
          if @pega_pedaco(ir,0,0)==1   # DIV com Carry
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
        if @pega_pedaco(ir,6,6)!=0 # Dec Rx
          @reg[rx] = @reg[rx] - 2

        @fr[3] = 0 # -- @fr = <...|zero|equal|lesser|greater>
        if(!@reg[rx])
          @fr[3] = 1  # Se resultado = 0, seta o Flag de Zero

      when Mnemonics.SHIFT
        @fr[3] = 0 # -- @fr = <...|zero|equal|lesser|greater>

        if(!@reg[rx])
          @fr[3] = 1  # Se resultado = 0, seta o Flag de Zero

        switch @pega_pedaco(ir,6,4)
          when 0
            @reg[rx] = @reg[rx] << @pega_pedaco(ir,3,0)
          when 1
            @reg[rx] = ~((~(@reg[rx]) << @pega_pedaco(ir,3,0)))
          when 2
            @reg[rx] = @reg[rx] >> @pega_pedaco(ir,3,0)
          when 3
            @reg[rx] = ~((~(@reg[rx]) >> @pega_pedaco(ir,3,0)))

            if(@pega_pedaco(ir,6,5)==2) # ROTATE LEFT
              @reg[rx] = _rotl(@reg[rx],@pega_pedaco(ir,3,0))
            else #TODO verificar
              @reg[rx] = _rotr(@reg[rx],@pega_pedaco(ir,3,0))

      when Mnemonics.SETC
        @fr[4] = @pega_pedaco(ir,9,9)

      when Mnemonics.HALT
        @switchMode()

      when Mnemonics.BREAKP
        @switchMode()

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
        undefined
        #@notifyProcessamento()

      when Mnemonics.HALT
        undefined
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
