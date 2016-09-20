module.exports =
class Video
  constructor: ->
    @sprites = new Array(2048)
    @oam = new Array(512)
    @oam[i] = {
        x: 0
        y: 0
        c: 0
        p: 0
        v: 0
        h: 0
      } for i in [0..512]
    @bg = new Array(1200)
    @bg[i] = {
        c: 0
        v: 0
        h: 0
        p: 0
      } for i in [0..1200]
    @palette = new Array(128)
    @palette[i] = {
      red: 0
      green: 0
      blue: 0
    } for i in [0..128]
    @addrSprite = 0
    @addrOAM  = 0
    @addrBG = 0
    @addrPalette = 0

  addSprite: (data) ->
    @sprites[@addrSprite] = data & 0xFFFF;
    @addrSprite = (@addrSprite+1) %2048;
    undefined

  addObject: (data) ->
    if (@addrOAM & 3) == 0
      @oam[@addrOAM>>2].x = data
    else if (@addrOAM & 3) == 1
      @oam[@addrOAM>>2].y = data
    else if (@addrOAM & 3) == 2
      @oam[@addrOAM>>2].c = data
    else if (@addrOAM & 3) == 3
      @oam[@addrOAM>>2].p = (data & 0x1F)
      @oam[@addrOAM>>2].v = (data>>8 & 0x1)
      @oam[@addrOAM>>2].h = (data>>9 & 0x1)
    @oam[@addrOAM>>2].dirty= true
    @addrOAM = ((@addrOAM+1) %512);
    undefined

  addBG: (data) ->
    @bg[@addrBG] = {
      c: (data & 0xFF)
      v: (data>>8 & 0x1)
      h: (data>>9 & 0x1)
      p: (data>>10 & 0x1F)
      dirty: true
    }
    @addrBG = (@addrBG+1)%1200
    undefined

  addPalette: (data)->
    @palette[@addrPalette] = {
      red: (data>>10)&31
      green: (data>>5)&31
      blue:  (data)&31
    }
    @addrPalette = (@addrPalette+1) % 128
    undefined

  getSprites: () ->
    @sprites;

  getOAM: () ->
    @oam

  getBG: () ->
    @bg

  getPalette: () ->
    @palette

  setAddrSprite: (addr) ->
    @addrSprite = addr
    undefined

  setAddrOAM: (addr) ->
    @addrOAM = addr
    undefined

  setAddrPalette: (addr) ->
    @addrPalette = addr
    undefined

  setAddrBG: (addr) ->
    @addrBG = addr
    undefined

  reset: () ->
    @sprites = new Array(2048)
    @oam = new Array(512)
    @oam[i] = {
        x: 0
        y: 0
        c: 0
        p: 0
        v: 0
        h: 0
      } for i in [0..512]
    @bg = new Array(1200)
    @bg[i] = {
        c: 0
        v: 0
        h: 0
        p: 0
      } for i in [0..1200]
    @palette = new Array(128)
    @palette[i] = {
      red: 0
      green: 0
      blue: 0
    } for i in [0..128]
    @addrSprite = 0
    @addrOAM  = 0
    @addrBG = 0
    @addrPalette = 0
    undefined
