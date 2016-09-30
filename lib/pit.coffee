module.exports =
class PIT
  constructor: (@simulator) ->
    @timersIntervals = [null,null,null]
    @timers = [0,0,0,0]

  set: (addr, data) ->
    switch addr
      when 0
        @timers[0] = data
        clearInterval @timersIntervals[0] if @timersIntervals[0]
        @timersIntervals[0] = setInterval(=>
          @simulator.setIRQ 1, 1
        ,10*@timers[0]) if not data%1
      when 1
        @timers[1] = data
        clearInterval @timersIntervals[1] if @timersIntervals[1]
        @timersIntervals[1] = setInterval(=>
          @simulator.setIRQ 1, 1
        ,100*@timers[1]) if not (data>>1)&1
      when 2
        @timers[2] = data
        clearInterval @timersIntervals[2] if @timersIntervals[2]
        @timersIntervals[2] = setInterval(=>
          @simulator.setIRQ 1, 1
        ,1000*@timers[2]) if not (data>>2)&1
      when 3
        @timers[3]=data
        clearInterval @timersIntervals[0] if @timersIntervals[0]
        @timersIntervals[0] = setInterval(=>
          @simulator.setIRQ 1, 1
        ,10*@timers[0]) if data&1

        clearInterval @timersIntervals[1] if @timersIntervals[1]
        @timersIntervals[1] = setInterval(=>
          @simulator.setIRQ 1, 1
        ,100*@timers[1]) if not (data>>1)&1

        clearInterval @timersIntervals[2] if @timersIntervals[2]
        @timersIntervals[2] = setInterval(=>
          @simulator.setIRQ 1, 1
        ,1000*@timers[2]) if not (data>>2)&1
    undefined

  get: (addr) ->
    @timers[addr]
    undefined

  clear: ->
    clearInterval @timersIntervals[0] if @timersIntervals[0]
    clearInterval @timersIntervals[1] if @timersIntervals[1]
    clearInterval @timersIntervals[2] if @timersIntervals[2]
    @timers = [0,0,0,0]
    undefined
