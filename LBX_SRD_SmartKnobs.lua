-- @version 0.01 
-- @author LBX
-- @changelog

--[[
   * ReaScript Name: SRD Smart Knobs
   * Lua script for Cockos REAPER
   * Author: Leon Bradley (LBX)
   * Author URI: 
   * Licence: GPL v3
  ]]
  
  tab_automode = {'Trim/Read','Read','Touch','Write','Latch','Latch Preview'}
  tab_amcol = {'205 205 205','128 128 128','128 128 128','128 128 128','128 128 128','160 128 255'}
  
  local lvar = {}
  local settings = {}
  local paths = {}

  lvar.deffloattime = 2  
    
  local contexts = {sliderctl = 0,
                    sliderctl_h = 1}
  
  pi = 3.14159265359
    
  --------------------------------------------
  --------------------------------------------
        
  function GetTrack(t)
  
    local tr
    if t == nil or t == 0 then
      track = reaper.GetMasterTrack(0)
    else
      track = reaper.GetTrack(0, t-1)
    end
    return track
  
  end
  
  function SetAutoMode(trn, m)
  
    local track = GetTrack(trn)
    reaper.SetTrackAutomationMode(track, m)
  
  end
  
  function Menu_AutoMode(trn)
  
    --set automode to trim/read
    local track = GetTrack(trn)
    local am = reaper.GetTrackAutomationMode(track, 0)
  
    local mstr = ''
    for i = 1, #tab_automode do
      if i > 1 then
        mstr = mstr..'|'
      end
      mstr = mstr..tab_automode[i]
    end
    gfx.x, gfx.y = mouse.mx, mouse.my
    local res = gfx.showmenu(mstr)
    return res-1
  
  end
  
  function GetCTLTrack()
    
    for i = 1, reaper.CountTracks(0) do
      local track = GetTrack(i)
      if track ~= nil then
        local trname, _ = reaper.GetTrackState(track)  
        if trname == LBX_CTL_TRNAME then
          LBX_CTL_TRACK = i
          LBX_CTL_TRACK_GUID = reaper.GetTrackGUID(track)
          LBX_CTL_TRACK_INF = {count = reaper.TrackFX_GetCount(track),
                               guids = {}}
                               
          if LBX_CTL_TRACK_INF.count > 0 then                     
            for f = 0, LBX_CTL_TRACK_INF.count-1 do
              LBX_CTL_TRACK_INF.guids[f] = reaper.TrackFX_GetFXGUID(track,f)
            end
          end
          control_cnt = LBX_CTL_TRACK_INF.count * 32
          return track
        end
      end
    end
    
  end
  
  function round(num, idp)
    --if tonumber(num) == nil then return num end    
    local mult = 10^(idp or 0)
    return math.floor(num * mult + 0.5) / mult
  end
  
  function CheckCTLGUID()
    local track = GetTrack(LBX_CTL_TRACK)
    if track and reaper.GetTrackGUID(track) == LBX_CTL_TRACK_GUID then
      CTMISSING = nil
      return true, track
    else
      LBX_CTL_TRACK = nil
      local track = GetCTLTrack()
      if track then CTMISSING = nil else CTMISSING = true end
      return false, track
    end 
  end
  
  function GetFaderBoxVals()
  
    ret = false
    if FFX and LBX_CTL_TRACK then
      
      fbvals = {}
      local track = GetTrack(LBX_CTL_TRACK)
      local track2 = GetTrack(FFX.trn)
      local fxnum2 = FFX.fxnum
      local fxnum = 0

      if track then
        for i = 1, control_cnt do
      
          fxnum = math.floor((i-1) / 32)
          
          local val = reaper.TrackFX_GetParamNormalized(track, fxnum, (i-1) % 32)
          val = round(val,5)
          if template.pos[i] and tostring(template.pos[i].val) ~= tostring(val) then

            if recmode == 1 then
              if fader_touch[i] == nil then
                fader_touch[i] = true
                local ctltrack = GetTrack(LBX_CTL_TRACK)
                local env = reaper.GetFXEnvelope(ctltrack, math.floor((i-1)/32), (i-1) % 32, true)
                ArmEnv(env, false)
              end
            end
            
            template.pos[i].val = val
            local pnum = template.pos[i].pnum
            
            reaper.TrackFX_SetParamNormalized(track2, fxnum2, pnum, val)            
            fbvals[i] = val
            template.dirty[i] = true
            
            update_fader = true
            ret = true
          
            if settings.floatfxgui ~= 0 then
              OpenFXGUI(track2, fxnum2)
            end
            
          end
      
        end
      end
    end
    return ret
    
  end

  function SetFaderBoxVal(i, v, track)
     if LBX_CTL_TRACK then
      local track = track or GetTrack(LBX_CTL_TRACK)
      if track then
        local fxnum = math.floor((i-1) / 32)
        local pnum = (i-1) % 32
        reaper.TrackFX_SetParamNormalized(track, fxnum, pnum, v)
      end
    end
      
  end
  
  function DBG(str)
    if str==nil then str="nil" end
    reaper.ShowConsoleMsg(tostring(str).."\n")
  end        
  ------------------------------------------------------------
  
  function GetObjects()
    local obj = {}
      
    obj.sections = {}
    local num = 7
    
    local pw =  math.floor(gfx1.main_w/2)-10

    fader_w = math.min(math.max(gfx1.main_w-70-pw,50),200)
    fader_h = 26
    fader_space = 4
    butt_h = 26
    
    pname_w = gfx1.main_w - fader_w - 70
    
    --pname
    obj.sections[2] = {x = 50,
                       y = 50,
                       w = pname_w,
                       h = gfx1.main_h-10}
    --slider
    obj.sections[1] = {x = obj.sections[2].x + obj.sections[2].w + 10,
                       y = obj.sections[2].y,
                       w = fader_w,
                       h = obj.sections[2].h}
    
    --temp pnum
    obj.sections[4] = {x = 10,
                       y = obj.sections[2].y,
                       w = 30,
                       h = gfx1.main_h-10}

    --learn
    obj.sections[9] = {x = 4, --+butt_h/4,
                       y = 6,
                       w = 40,
                       h = 18}
    obj.sections[8] = {x = 4,
                       y = 26,
                       w = 40,
                       h = 18}
                       
    --rec mode
    obj.sections[6] = {x = math.max(obj.sections[8].x+obj.sections[8].w+10, obj.sections[1].x+obj.sections[1].w-130),
                       y = 12,
                       w = 60,
                       h = butt_h}
    --save
    obj.sections[5] = {x = math.max(obj.sections[8].x+obj.sections[8].w+10 ,obj.sections[6].x+obj.sections[6].w+10),
                       y = 12,
                       w = 60,
                       h = butt_h}
    --fxname
    local xx = obj.sections[8].x+ obj.sections[8].w+4
    obj.sections[3] = {x = xx,
                       y = 12,
                       w = obj.sections[6].x - xx-4,
                       h = butt_h}
    obj.sections[7] = {x = xx,
                       y = 0,
                       w = obj.sections[6].x - xx-4,
                       h = butt_h-4}
                               
    return obj
  end
  
  -----------------------------------------------------------------------     
  
  function GetGUI_vars()
    gfx.mode = 0
    
    local gui = {}
      gui.aa = 1
      gui.fontname = 'Calibri'
      gui.fontsize_tab = 20    
      gui.fontsz_knob = 18
      if OS == "OSX32" or OS == "OSX64" then gui.fontsize_tab = gui.fontsize_tab - 5 end
      if OS == "OSX32" or OS == "OSX64" then gui.fontsz_knob = gui.fontsz_knob - 5 end
      if OS == "OSX32" or OS == "OSX64" then gui.fontsz_get = gui.fontsz_get - 5 end
      
      gui.color = {['back'] = '87 109 130',
                    ['back2'] = '87 109 130',
                    ['black'] = '0 0 0',
                    ['green'] = '87 109 130',
                    ['blue'] = '87 109 130',
                    ['white'] = '255 255 255',
                    ['red'] = '255 42 0',
                    ['green_dark'] = '0 0 0',
                    ['yellow'] = '87 109 130',
                    ['pink'] = '87 109 130',
                    }
    return gui
  end  
  ------------------------------------------------------------
      
  function f_Get_SSV(s)
    if not s then return end
    local t = {}
    for i in s:gmatch("[%d%.]+") do 
      t[#t+1] = tonumber(i) / 255
    end
    gfx.r, gfx.g, gfx.b = t[1], t[2], t[3]
  end
  
  function f_Get_SSV_fade(s1, s2, p)
    if not s1 or not s2 then return end
    local t, d = {}, {}
    for i in s1:gmatch("[%d%.]+") do 
      t[#t+1] = tonumber(i) / 255
    end
    for i in s2:gmatch("[%d%.]+") do
      local x = #d+1 
      d[x] = (tonumber(i) / 255) - t[x]
    end
    
    gfx.r, gfx.g, gfx.b = t[1]+d[1]*p, t[2]+d[2]*p, t[3]+d[3]*p
  end
  ------------------------------------------------------------
    
  function GUI_text(gui, xywh, text, flags, col, tsz)

    if col == nil then col = gui.color.white end
    if tsz == nil then tsz = 0 end
    
    f_Get_SSV(col)  
    gfx.a = 1 
    gfx.setfont(1, gui.fontname, gui.fontsz_knob+tsz)
    --local text_len = gfx.measurestr(text)
    gfx.x, gfx.y = xywh.x,xywh.y
    gfx.drawstr(text, flags, xywh.x+xywh.w, xywh.y+xywh.h)

  end
  
  ------------------------------------------------------------
  
  function GUI_draw(obj, gui)
    
    gfx.mode =4
    gfx.dest = 1

    if update_gfx or resize_display then    
      gfx.setimgdim(1, -1, -1)  
      gfx.setimgdim(1, gfx1.main_w,gfx1.main_h)
      
      f_Get_SSV(colours.mainbg)
      gfx.rect(0,
               0,
               gfx1.main_w,
               gfx1.main_h, 1)  
    end

    if update_gfx or update_fader then    

      if update_gfx then
        GUI_DrawFXHeader(obj, gui)
        GUI_DrawButtons(obj, gui)
      end
      
      GUI_DrawFaders(obj, gui)

    end
    
    if LBX_CTL_TRACK == nil then
    
      xywh = {x = obj.sections[4].x, y = obj.sections[4].y, w = obj.sections[1].x+obj.sections[1].w-obj.sections[4].x, h = obj.sections[4].h}
      GUI_DrawButton(gui, xywh, 'CONTROL TRACK NOT FOUND', '25 25 25', '255 0 0', true, 4)
    
    end
        
    gfx.dest = -1
    gfx.a = 1
    gfx.blit(1, 1, 0, 
      0,0, gfx1.main_w,gfx1.main_h,
      0,0, gfx1.main_w,gfx1.main_h, 0,0)
    update_gfx = false
    update_fader = false
    resize_display = false
    
  end

  function GUI_FlashButton(obj, gui, butt, txt, flashtime, col)

    gfx.dest = 1
    GUI_DrawButton(gui, obj.sections[butt], txt, col, '99 99 99', true, -1)
    gfx.dest = -1
    gfx.a = 1
    gfx.blit(1, 1, 0, 
      0,0, gfx1.main_w,gfx1.main_h,
      0,0, gfx1.main_w,gfx1.main_h, 0,0)
    refresh_gfx = reaper.time_precise() + flashtime
      
  end
  
  function GUI_DrawButtons(obj, gui)

    local c = colours.buttcol
    --[[if flashctl[5] == true then
      flashctl[5] = nil
      c = '255 0 0'
    end]]
    if recmode == 1 then
      c = '205 205 205'
    end
    GUI_DrawButton(gui, obj.sections[5], 'SAVE', c, '99 99 99', true, -1)
    local bc = colours.buttcol
    if recmode == 0 then
    elseif recmode == 1 then
      bc = '255 0 0'
    end
    GUI_DrawButton(gui, obj.sections[6], 'REC', bc, '99 99 99', true, -1)
    
    local bc = colours.buttcol
    if lrnmode == false then
    elseif lrnmode == true then
      bc = '255 0 0'
    end
    GUI_DrawButton(gui, obj.sections[8], 'LEARN', bc, '99 99 99', true, -4)
    local bc = colours.buttcol
    GUI_DrawButton(gui, obj.sections[9], 'SETTINGS', bc, '99 99 99', true, -8)

  end

  function GUI_DrawButton(gui, xywh, txt, bcol, tcol, val, tsz)
  
    f_Get_SSV(bcol)
    gfx.rect(xywh.x,
             xywh.y,
             xywh.w,
             xywh.h, 1)
    GUI_text(gui, xywh, txt, 5, tcol, tsz)
    
  end
  
  function GUI_DrawFXHeader(obj, gui)

    if FFX then
    
      f_Get_SSV(colours.mainbg)
      gfx.rect(obj.sections[3].x,
               obj.sections[3].y,
               obj.sections[3].w,
               obj.sections[3].h, 1)
      GUI_text(gui, obj.sections[3], FFX.fxname, 5, tab_amcol[LBX_FX_TRACK_AM+1], 2)
      GUI_text(gui, obj.sections[7], '('..FFX.fxtype..')', 5, '99 99 99', -5)
    
    end

  end
    
  function GUI_DrawFaders(obj, gui)
  
    local viscnt = math.floor(obj.sections[1].h/(fader_h + fader_space))
    
    for i = 1, viscnt do
      if i+control_offs <= control_cnt and (update_gfx == true or (template.dirty[i+control_offs] == true) or template.sft[i+control_offs]) then
        GUI_DrawFader(obj, gui, i)
      end
      
    end
  
  end
  
  function GUI_DrawFader(obj, gui, i)
    local y = (i-1) * (fader_h+fader_space)
    local fv = 0
    if template.pos[i+control_offs] then
      fv = F_limit(template.pos[i+control_offs].val,0,1)
    end
    
    f_Get_SSV(colours.faderbg)
    gfx.rect(obj.sections[1].x,
             obj.sections[1].y + y,
             fader_w,
             fader_h, 1)
             
    if template.pos[i+control_offs] then
      f_Get_SSV(colours.faderborder)
      gfx.rect(obj.sections[1].x,
               obj.sections[1].y + y,
               fader_w,
               fader_h, 1)
      f_Get_SSV(colours.faderbg2)
      gfx.rect(obj.sections[1].x+2,
               obj.sections[1].y + y+2,
               fader_w-4,
               fader_h-4, 1)

      if update_gfx == false and template.dirty[i+control_offs] == true then
        f_Get_SSV(colours.faderlit)
        template.sft[i+control_offs] = reaper.time_precise() + fadedel_s
        template.eft[i+control_offs] = reaper.time_precise() + fadedel_e
        --sfade = math.min(sfade or template.sft[i+control_offs], template.sft[i+control_offs])
        --efade = math.max(efade or template.eft[i+control_offs], template.eft[i+control_offs])
        template.dirty[i+control_offs] = nil
        
      elseif template.sft[i+control_offs] and template.sft[i+control_offs] > reaper.time_precise() then
        f_Get_SSV(colours.faderlit)

      elseif template.sft[i+control_offs] and template.sft[i+control_offs] <= reaper.time_precise() and template.eft[i+control_offs] > reaper.time_precise() then
        local fade = inSine((reaper.time_precise() - template.sft[i+control_offs]) / (template.eft[i+control_offs] - template.sft[i+control_offs]))
        f_Get_SSV_fade(colours.faderlit, colours.fader, fade)

      elseif template.eft[i+control_offs] and template.eft[i+control_offs] <= reaper.time_precise() then
      
        template.sft[i+control_offs] = nil
        template.eft[i+control_offs] = nil
        sfade = nil
        efade = nil
        f_Get_SSV(colours.fader)
        template.dirty[i+control_offs] = nil
      else

        f_Get_SSV(colours.fader)
        template.dirty[i+control_offs] = nil
      end
      gfx.rect(obj.sections[1].x+4,
               obj.sections[1].y + y+4,
               (fader_w-8)*fv,
               fader_h-8, 1)
    end
    
    local pname, c, f
    if template.pos[i+control_offs] then
      pname = template.pos[i+control_offs].pname
      if update_gfx == false and template.dirty[i+control_offs] == true then
        col = colours.pnamelit
      else
        col = gui.color.blue      
      end
      bcol = '15 15 15'
      f = 1
    else
      pname = ''
      col = gui.color.red
      bcol = '25 25 25'
      f = 1
    end
    local xywh = {x = obj.sections[2].x,
                  y = obj.sections[2].y +y,
                  w = obj.sections[2].w,
                  h = fader_h}
    
    f_Get_SSV(bcol)
    gfx.rect(xywh.x,
             xywh.y,
             xywh.w,
             xywh.h, f)
                      
    GUI_text(gui, xywh, pname, 5, col, -1)
    local xywh = {x = obj.sections[4].x,
                  y = obj.sections[4].y +y,
                  w = obj.sections[4].w,
                  h = fader_h}
    
    if recmode == 1 and fader_touch[i] then
      col = '205 205 205'
    end
    f_Get_SSV(col)
    gfx.rect(xywh.x,
             xywh.y,
             xywh.w,
             xywh.h, 1)
    GUI_text(gui, xywh, string.format('%i',round(i+control_offs)), 5, gui.color.black, 1)
    
  end  

  function inCubic(t)
    return t^3
  end
  
  function outCubic(t)
    if t < 0 then
      t = -t - 1
      return -(t^3 + 1)
    else
      t = t - 1
      return t^3 + 1
    end
  end
  
  function inSine(t)
    if t < 0 then
      return -(-1 * math.cos(-t * (pi / 2)) + 1)
    else
      return -1 * math.cos(t * (pi / 2)) + 1
    end
  end
  
  function outSine(t)
    return 1 * math.sin(t * (pi / 2))
  end
    
  ------------------------------------------------------------
  
  function Lokasenna_Window_At_Center (w, h)
    -- thanks to Lokasenna 
    -- http://forum.cockos.com/showpost.php?p=1689028&postcount=15    
    local l, t, r, b = 0, 0, w, h    
    local __, __, screen_w, screen_h = reaper.my_getViewport(l, t, r, b, l, t, r, b, 1)    
    local x, y = (screen_w - w) / 2, (screen_h - h) / 2    
    gfx.init("SRD SMART CONTROL", w, h, 0, x, y)  
  end

 -------------------------------------------------------------     
      
  function F_limit(val,min,max)
      if val == nil or min == nil or max == nil then return end
      local val_out = val
      if val < min then val_out = min end
      if val > max then val_out = max end
      return val_out
    end   
  ------------------------------------------------------------
  
  --[[function MOUSE_slider(b)
    if mouse.mx > b.x and mouse.mx < b.x+b.w
      --and mouse.my > b.y and mouse.my < b.y+b.h 
      and mouse.LB then
     return math.floor(100*(mouse.mx-40) / (b.w-80))/100
    end 
  end]]
  
  function MOUSE_slider_horiz(b,xoff)
    if mouse.LB then
      if xoff == nil then xoff = 0 end
      local mx = mouse.mx - (b.x-200) + xoff
     return (mx) / (b.w+400)
    end 
  end
  
  function MOUSE_slider_horiz2(b,xoff)
    if mouse.LB then
      if xoff == nil then xoff = 0 end
      local mx = mouse.mx - (b.x)
     return (mx) / (b.w)
    end 
  end
  
  function MOUSE_slider(b,yoff)
    if mouse.LB then
      if yoff == nil then yoff = 0 end
      local my = mouse.my - (b.y-200) + yoff
     return (my) / (b.h+400)
      --local my = mouse.my - b.y - yoff
      --return (my+200) / 400
    end 
  end
    
  function MOUSE_click(b)
    if mouse.mx > b.x and mouse.mx < b.x+b.w
      and mouse.my > b.y and mouse.my < b.y+b.h 
      and mouse.LB 
      and not mouse.last_LB then
     return true 
    end 
  end

  function MOUSE_click_RB(b)
    if mouse.mx > b.x and mouse.mx < b.x+b.w
      and mouse.my > b.y and mouse.my < b.y+b.h 
      and mouse.RB 
      and not mouse.last_RB then
     return true 
    end 
  end

  function MOUSE_over(b)
    if mouse.mx > b.x and mouse.mx < b.x+b.w
      and mouse.my > b.y and mouse.my < b.y+b.h 
      then
     return true 
    end 
  end
  
  ------------------------------------------------------------

  function GetTrackChunk(track)
    if not track then return end
    local fast_str, track_chunk
    fast_str = reaper.SNM_CreateFastString("")
    if reaper.SNM_GetSetObjectState(track, fast_str, false, false) then
    track_chunk = reaper.SNM_GetFastString(fast_str)
    end
    reaper.SNM_DeleteFastString(fast_str)  
    return track_chunk
  end

  function SetTrackChunk(track, track_chunk)
    if not (track and track_chunk) then return end
    local fast_str, ret
    fast_str = reaper.SNM_CreateFastString("")
    if reaper.SNM_SetFastString(fast_str, track_chunk) then
      ret = reaper.SNM_GetSetObjectState(track, fast_str, true, false)
    end
    reaper.SNM_DeleteFastString(fast_str)
    return ret
  end
  
  function GetFocusedFX(force)
  
    local FFX
    local ret, trn, itmnum, fxnum = reaper.GetFocusedFX()
    if trn ~= LBX_CTL_TRACK and recmode == 0 then
      if ret == 0 then
        
        FFX = nil
        
      elseif ret == 1 then
        --Track FX
        local track = GetTrack(trn)
        if track then
          local ret, fxname = reaper.TrackFX_GetFXName(track, fxnum, '')
          local fxguid = reaper.TrackFX_GetFXGUID(track, fxnum)
          if fxguid ~= ofxguid or force == true then
            ofxguid = fxguid
            local _,fx = GetFXChunkFromTrackChunk(track, fxnum+1)
            if fx then
              fx = string.match(fx, '.-<(.*)')
              local fxnm, fxtype = GetPlugNameFromChunk(fx)
              fxname = TrimFXName(fxname)
              FFX = {trn = trn,
                     trguid = reaper.GetTrackGUID(track),
                     fxnum = fxnum,
                     fxname = fxname,
                     fxplug = fxnm,
                     fxguid = fxguid,
                     fxtype = fxtype}
            else
              local trchunk = GetTrackChunk(track)
              
              local ffn=paths.resource_path..'chunkerror.txt'
              
              file=io.open(ffn,"w")
              file:write('fxnum: '..fxnum+1 ..'\n')
              file:write(trchunk)
              file:close()
              DBG('Chunk error file created at: '..ffn)
              
            end
          else
            
          end
        end      
      elseif ret == 2 then
        --Item FX
      
      end
    end
      
    return FFX, ret
    
  end

  function GetPlugNameFromChunk(fxchunk)
  
    local fxn, fxt
    local s,e = string.find(fxchunk,'.-(\n)')
    local fxc = string.sub(fxchunk,1,e)
    if string.sub(fxc,1,3) == 'VST' then
      if string.match(fxc, '.-(VST3).-\n') then
        fxt = 'VST3'
      else
        fxt = 'VST'
      end
      fxn = string.match(fxc, '.-: (.-) %(')
      if fxn == nil then
        fxn = string.match(fxc, '.-: (.-)%"')      
      end
    elseif string.sub(fxc,1,2) == 'JS' then
      fxt = 'JS'
      fxn = string.match(fxc, 'JS.*%/+(.-) \"')
      if fxn == nil then
        fxn = string.match(fxc, 'JS%s(.-)%s')  -- gets full path of effect
        fxn = string.match(fxn, '([^/]+)$') -- gets filename  
      end
      --remove final " if exists
      if string.sub(fxn,string.len(fxn)) == '"' then
        fxn = string.sub(fxn,1,string.len(fxn)-1)
      end
      
      --[[if fxn == nil then
        --JS \"AB Level Matching JSFX [2.5]/AB_LMLT_cntrl\" \"MSTR /B\"\
        fxn = string.match(fxchunk, 'JS.*%/(.-)%"%\"')
        fxn = string.sub(fxn,1,string.len(fxn)-2)
      end]]
    end
  
    return fxn, fxt
    
  end
  
  --returns success, fxchunk, start loc, end loc
  function GetFXChunkFromTrackChunk(track, fxn)
  
    --local ret, trchunk = reaper.GetTrackStateChunk(track,'')
    local trchunk = GetTrackChunk(track)
    if trchunk then
      local s,e, fnd = 0,0,nil
      for i = 1,fxn do
        s, e = string.find(trchunk,'(BYPASS.-WAK %d)',s)
        if s and e then
          fxchunk = string.sub(trchunk,s,e)
    
          if i == fxn then fnd = true break end
          s=e+1
        else
          fxchunk = nil
          fnd = nil
          break
        end
      end
      return fnd, fxchunk, s, e  
    end
      
  end
    
  function GetParams()

  end

  function SetParam()

  end
  
  function SetTemplateParam(temppos, paramnum, paramname) 
  
    template.pos[temppos] = {pnum = paramnum,
                             pname = paramname,
                             val = nil,}
  
  end
  
  function ParamMenu()
  
    if FFX then
      local menustr = 'Clear|'
      local pnames = {}
      local track = GetTrack(FFX.trn)
      local numparams = reaper.TrackFX_GetNumParams(track, FFX.fxnum)
      for p = 0, numparams do
        local ret, pname = reaper.TrackFX_GetParamName(track, FFX.fxnum, p, '')
        pnames[p] = pname
        menustr = menustr..'|'..pname
      end
      
      gfx.x, gfx.y = mouse.mx, mouse.my
      local res = gfx.showmenu(menustr)
      if res > 0 then
        if res == 1 then
          return -1
        else
          return res -2, pnames[res-2]
        end
      end
    end
      
  end
  
  function TrimFXName(fxname)
  
    local fxn = string.match(fxname, '.-: (.+) %(')
    if fxn == nil then
      fxn = string.match(fxname, '.-: (.*)')
      if fxn == nil then
        fxn = fxname
      end
    end
    local fxn = string.gsub(fxn,'/','')
    return fxn
  
  end
  
  function LoadFXParamTemplate(ffx)
    template = {dirty = {},
                pos = {},
              sft = {},
              eft = {}}

    if ffx then
    
      local ffn=paths.template_path..TrimFXName(ffx.fxplug)..'_'..ffx.fxtype..'.smtemp'

      if reaper.file_exists(ffn) ~= true then
        ffn=paths.template_path..TrimFXName(ffx.fxplug)..'.smtemp'
        if reaper.file_exists(ffn) ~= true then
          return 0
        end
      end    
      
      local file
      
      data = {}
      for line in io.lines(ffn) do
        local idx, val = string.match(line,'%[(.-)%](.*)') --decipher(line)
        if idx then
          data[idx] = val
        end
      end
      
      settings.floatfxgui = 0
      if data['floatgui'] then
        settings.floatfxgui = tonumber(data['floatgui'])
      end
        
      for i = 1, control_max do
      
        local pfx = 'ctl_'..i..'_'
        local pnum = zn(data[pfx..'pnum'])
        if pnum then
          
          template.pos[i] = {pnum = pnum,
                             pname = zn(data[pfx..'pname'],'')}
        end
      
      end      

    end
  end
  
  function nz(val, d)
    if val == nil then return d else return val end
  end
  function zn(val, d)
    if val == '' or val == nil then return d else return val end
  end
  
  function SaveFXParamTemplate(ffx, template)
    if ffx then
    
      local ffn=paths.template_path..TrimFXName(ffx.fxplug)..'_'..ffx.fxtype..'.smtemp'
      
      file=io.open(ffn,"w")
      file:write('[floatgui]'..(settings.floatfxgui or 0)..'\n')
      
      for i = 1, control_max do
      
        if template.pos[i] then
          local pfx = 'ctl_'..i..'_'
          file:write('[' .. pfx ..'pnum]'..template.pos[i].pnum..'\n')
          file:write('[' .. pfx ..'pname]'..template.pos[i].pname..'\n')
        end
      
      end
      file:close()
          
    end
  end
  
  function ReadParamVals(upd_fb)
  
    if FFX then
    
      local track = GetTrack(FFX.trn)
      if FFX.trguid ~= reaper.GetTrackGUID(track) then
        local ret
        FFX, ret = GetFocusedFX(true)
        if ret == 1 then
          track = GetTrack(FFX.trn)
        end
      end
      
      if track then
        local ctltrack = GetTrack(LBX_CTL_TRACK)
      
        for i = 1, control_cnt do
      
          if template.pos[i] then
            local fxnum = FFX.fxnum
            local pnum = template.pos[i].pnum
            --DBG(i.. '  '..pnum)
            local val = round(reaper.TrackFX_GetParamNormalized(track, fxnum, pnum),5)
            if template.pos[i].val ~= val then
            
              --val = round(val,5)
              template.pos[i].val = val
              template.dirty[i] = true
              update_fader = true
              
              if upd_fb == true then
                SetFaderBoxVal(i, val)
              end
              
            end
          else
            if upd_fb == true then
              local fxnum = math.floor((i-1)/32)
              local pnum = (i-1) % 32
              local val = round(reaper.TrackFX_GetParamNormalized(ctltrack, fxnum, pnum),5)
              if val ~= 0 then
                SetFaderBoxVal(i, 0)
              end
            end
          end
        end
        
      end
    end
  
  end
  
  function OpenFXGUI(track,fxnum)
  
    local fxopentimerset = false
    if reaper.TrackFX_GetOpen(track, fxnum) ~= true then
      reaper.TrackFX_Show(track,fxnum,3)
      fxopentimerset = true
    end
    if lvar.fxopentimer or fxopentimerset == true then
      lvar.fxopentimer = reaper.time_precise() + settings.floatfxgui
      lvar.fxopeninfo = {track = track,
                         fxnum = fxnum}
    end
    
  end
  function CloseFXGUI(track,fxnum)
    reaper.TrackFX_Show(track,fxnum,2)
  end
  
  function SetRecMode(m)
  
    if LBX_CTL_TRACK and FFX then
      
      if m == 0 then
        --Set CTL TRACK to read/trim
        --Copy Envelope range to target param envelope
        local ctltrack = GetTrack(LBX_CTL_TRACK)
        local tgttrack = GetTrack(FFX.trn)
        
        local start_time, end_time = reaper.GetSet_LoopTimeRange2(0, false, false, 0, 0, false)

        
        if start_time ~= end_time then
          for i = 1, control_cnt do
            if fader_touch[i] == true then

               local srcenv = reaper.GetFXEnvelope(ctltrack, math.floor((i-1)/32), (i-1) % 32, false)
              local dstenv = reaper.GetFXEnvelope(tgttrack, FFX.fxnum, template.pos[i].pnum, true)
              if srcenv and dstenv then
                CopyEnv(srcenv, dstenv, start_time, end_time, true)
              end
              --disarm 

              local br_env = reaper.BR_EnvAlloc(srcenv, false)              
              local active, visible, armed, inLane, laneHeight, defaultShape, minValue, maxValue, centerValue, type, faderScaling = reaper.BR_EnvGetProperties(br_env, true, true, true, true, 0, 0, 0, 0, 0, 0, true)
              reaper.BR_EnvSetProperties(br_env, active, false, true, inLane, laneHeight, defaultShape, faderScaling)              
              reaper.BR_EnvFree(br_env, false)
            end
          end
        end
              
        --Remove envelopes
        for i = 0, control_cnt-1 do
          ClearEnvelope(LBX_CTL_TRACK, i)
        end
        reaper.UpdateArrange()
        SetAutoMode(LBX_CTL_TRACK, 0)
        SetAutoMode(FFX.trn, LBX_FX_TRACK_AM)
        
        reaper.Undo_EndBlock("LBX Record Automation", 0) -- End of the undo block. Leave it at the bottom of your main function.
        
      elseif m == 1 then
      
        reaper.Undo_BeginBlock()
      
        --set CTL TRACK to rec latch
        --reset fader touched table
        local ctltrack = GetTrack(LBX_CTL_TRACK)
        for i = 0, control_cnt-1 do
          
          if template.pos[i] then
            local srcenv = reaper.GetFXEnvelope(ctltrack, 0, i-1, true)
            
            if srcenv then
              local br_env = reaper.BR_EnvAlloc(srcenv, false)              
              local active, visible, armed, inLane, laneHeight, defaultShape, minValue, maxValue, centerValue, type, faderScaling = reaper.BR_EnvGetProperties(br_env, true, true, true, true, 0, 0, 0, 0, 0, 0, true)
              reaper.BR_EnvSetProperties(br_env, active, visible, true, inLane, laneHeight, defaultShape, faderScaling)              
              reaper.BR_EnvFree(br_env, true)
            end
          end
          --ShowEnvelope(LBX_CTL_TRACK, i)
        end
        reaper.UpdateArrange()
        SetAutoMode(LBX_CTL_TRACK, LBX_CTL_TRACK_AM)
        SetAutoMode(FFX.trn, 5)
        fader_touch = {}
      
      elseif m == -1 then
        --CLEAR REC MODE
        recmode = 0
        
        --Remove envelopes
        for i = 0, control_cnt-1 do
          ClearEnvelope(LBX_CTL_TRACK, i)
          
        end
        reaper.UpdateArrange()
        SetAutoMode(LBX_CTL_TRACK, 0)
        SetAutoMode(FFX.trn, LBX_FX_TRACK_AM)
        
        reaper.Undo_EndBlock("LBX Record Automation", 0)

      end
    end
      
  end
  
  function ArmEnv(env, arm)

    if srcenv then
      local br_env = reaper.BR_EnvAlloc(srcenv, false)              
      local active, visible, armed, inLane, laneHeight, defaultShape, minValue, maxValue, centerValue, type, faderScaling = reaper.BR_EnvGetProperties(br_env, true, true, true, true, 0, 0, 0, 0, 0, 0, true)
      reaper.BR_EnvSetProperties(br_env, active, visible, arm, inLane, laneHeight, defaultShape, faderScaling)              
      reaper.BR_EnvFree(br_env, 1)
    end
  
  end
  
  function CopyEnv(srcenv, dstenv, start_time, end_time, preserve_edges)
  
    env_points_count = reaper.CountEnvelopePoints(srcenv)
    if env_points_count > 0 then
    
      retval3, valueOut3, dVdSOutOptional3, ddVdSOutOptional3, dddVdSOutOptional3 = reaper.Envelope_Evaluate(srcenv, start_time, 0, 0)
      retval4, valueOut4, dVdSOutOptional4, ddVdSOutOptional4, dddVdSOutOptional4 = reaper.Envelope_Evaluate(srcenv, end_time, 0, 0)
      
      if preserve_edges == true then
        retval6, valueOut6, dVdSOutOptional6, ddVdSOutOptional6, dddVdSOutOptional6 = reaper.Envelope_Evaluate(dstenv, end_time, 0, 0)
        retval5, valueOut5, dVdSOutOptional5, ddVdSOutOptional5, dddVdSOutOptional5 = reaper.Envelope_Evaluate(dstenv, start_time, 0, 0)
      end
      
      reaper.DeleteEnvelopePointRange(dstenv, start_time, end_time)
       
      for k = 0, env_points_count+1 do
        retval, time, valueOut, shape, tension, selectedOut = reaper.GetEnvelopePoint(srcenv, k)

        if time >= start_time and time <= end_time then
          reaper.InsertEnvelopePoint(dstenv, time, valueOut, shape, tension, 1, true)
        end
      
      end
    
      if preserve_edges == true then
        reaper.InsertEnvelopePoint(dstenv, start_time, valueOut5, 0, 0, true, true) -- INSERT start_time point
      end
        reaper.InsertEnvelopePoint(dstenv, start_time, valueOut3, 0, 0, true, true) -- INSERT start_time point
        reaper.InsertEnvelopePoint(dstenv, end_time, valueOut4, 0, 0, true, true) -- INSERT start_time point
      if preserve_edges == true then
        reaper.InsertEnvelopePoint(dstenv, end_time, valueOut6, 0, 0, true, true) -- INSERT start_time point
      end
      reaper.Envelope_SortPoints(dstenv)
    end
    
  end
  
  function RemoveEnv(env)
    retval, xml_env = reaper.GetEnvelopeStateChunk(env, "", false)
    xml_env = xml_env:gsub("\n", "¤¤")
    retval, xml_env = reaper.SetEnvelopeStateChunk(env, xml_env, false)
    return xml_env
  end
  
  function ClearEnvelope(trn, envn)
    local track = GetTrack(trn)
    if track then
      local env = reaper.GetFXEnvelope(track, math.floor(envn/32), envn % 32, false)
      if env then 
        --[[local plen = reaper.GetProjectLength(0)
        reaper.DeleteEnvelopePointRange(env,-10,plen+10)]]
        RemoveEnv(env)
      end
    end
  end
  
  ------------------------------------------------------------    
  
  function run()
  
    local rt = reaper.time_precise()  
    
    if gfx.w ~= last_gfx_w or gfx.h ~= last_gfx_h or force_resize or obj == nil then
      local r = false
      if not r or gfx.dock(-1) > 0 then 
        gfx1.main_w = gfx.w
        gfx1.main_h = gfx.h
        win_w = gfx.w
        win_h = gfx.h
  
        last_gfx_w = gfx.w
        last_gfx_h = gfx.h
                
        gui = GetGUI_vars()
        obj = GetObjects()
        
        resize_display = true
        update_gfx = true        
      end
    end
    if lrnmode == false then
      local ctlchk, track = CheckCTLGUID()
      local checkfx, ret = GetFocusedFX(not ctlchk)
      if checkfx and CTMISSING == nil and (FFX == nil or FFX.fxguid ~= checkfx.fxguid or ctlchk == false) then
        if FFX and FFX.trn ~= checkfx.trn then
          SetAutoMode(FFX.trn,LBX_FX_TRACK_DEFAM)
        end
        FFX = checkfx
        SetAutoMode(FFX.trn,LBX_FX_TRACK_AM)
        LoadFXParamTemplate(FFX)
        ReadParamVals(true)
  
          if CTMISSING == nil then
            update_gfx = true
          end
        
      elseif ret == 0 then
        FFX = nil
        ofxguid = nil
        template = {dirty = {},
                      pos = {},
              sft = {},
              eft = {}}
        update_gfx = true
      end
        
      local rv = GetFaderBoxVals()
      if recmode == 0 then
        ReadParamVals(true)
      end

    end

    GUI_draw(obj, gui)
    
    mouse.mx, mouse.my = gfx.mouse_x, gfx.mouse_y
    mouse.LB = gfx.mouse_cap&1==1
    mouse.RB = gfx.mouse_cap&2==2
    mouse.ctrl = gfx.mouse_cap&4==4
    mouse.shift = gfx.mouse_cap&8==8
    mouse.alt = gfx.mouse_cap&16==16
    
    -------------------------------------------

    if LBX_CTL_TRACK then
    
      if lrnmode == false then

        if lvar.fxopentimer and lvar.fxopentimer < reaper.time_precise() then
          CloseFXGUI(lvar.fxopeninfo.track,lvar.fxopeninfo.fxnum)
          lvar.fxopentimer = nil
          lvar.fxopeninfo = nil
        end
        
        if mouse.context == nil and gfx.mouse_wheel ~= 0 then
          local z = gfx.mouse_wheel / 120
          
          if MOUSE_over(obj.sections[2]) or MOUSE_over(obj.sections[1]) then
            control_offs = F_limit(control_offs-z,0,control_cnt-1)
            update_gfx = true
          end
          gfx.mouse_wheel = 0
     
        elseif mouse.context == nil and MOUSE_click(obj.sections[2]) then
        
          local i = math.floor((mouse.my - obj.sections[2].y) / (fader_h+fader_space))+1 +control_offs
          if i <= control_cnt and recmode == 0 then
         
            local p, pn = ParamMenu()
            if p then
              if p == -1 then          
                template.pos[i] = nil
                template.dirty[i] = true
              else
              --DBG(i..'  '..p..'  '..pn)
                SetTemplateParam(i, p, pn)
                
                local track = GetTrack(FFX.trn)
                local fxnum = FFX.fxnum
                local pnum = template.pos[i].pnum
                local val = reaper.TrackFX_GetParamNormalized(track, fxnum, pnum)
                template.pos[i].val = val
                SetFaderBoxVal(i, val)
                
                template.dirty[i] = true
              end
              update_fader = true
            end
          end
        
        elseif mouse.context == nil and MOUSE_click(obj.sections[1]) then
          local i = math.floor((mouse.my - obj.sections[1].y) / (fader_h+fader_space))+1 +control_offs
          if template.pos[i] then
        
            mouse.context = contexts.sliderctl
            mouse.slideoff = math.floor(obj.sections[1].x + fader_w/2 - mouse.mx)
            ctlpos = template.pos[i].val
            slider_select = i
            oms = mouse.shift
          end
    
        elseif mouse.context == nil and MOUSE_click(obj.sections[4]) then
          local i = math.floor((mouse.my - obj.sections[1].y) / (fader_h+fader_space))+1 +control_offs
    
          if recmode == 1 then
            if fader_touch[i] then 
              fader_touch[i] = nil
              local ctltrack = GetTrack(LBX_CTL_TRACK)
              local env = reaper.GetFXEnvelope(ctltrack, 0, i-1, true)
              ArmEnv(env, false)
            else
              fader_touch[i] = true
              local ctltrack = GetTrack(LBX_CTL_TRACK)          
              local env = reaper.GetFXEnvelope(ctltrack, 0, i-1, true)
              ArmEnv(env, false)
            end
            update_gfx = true
          end
          
        elseif mouse.context == nil and MOUSE_click(obj.sections[5]) then
        
          if recmode == 0 then
            SaveFXParamTemplate(FFX, template)
            GUI_FlashButton(obj, gui, 5, 'SAVE', 0.1, '205 205 205')
          else
            recmode = 0
            SetRecMode(recmode)
            update_gfx = true
          end
          
        elseif mouse.context == nil and MOUSE_click(obj.sections[6]) then
          
          if FFX and recmode == 0 then
            recmode = 1
            SetRecMode(recmode)
            update_gfx = true
          
          elseif FFX and recmode == 1 then
            recmode = -1
            SetRecMode(recmode)
            update_gfx = true
          
          end
              
        elseif mouse.context == nil and MOUSE_click_RB(obj.sections[6]) then
        
          local ret = Menu_AutoMode(LBX_CTL_TRACK)
          if ret >= 0 then
            LBX_CTL_TRACK_AM = ret
          end
        
        elseif mouse.context == nil and MOUSE_click(obj.sections[3]) then
        
          if FFX then
          
            if LBX_FX_TRACK_AM == 0 then
              LBX_FX_TRACK_AM = 5
            else
              LBX_FX_TRACK_AM = 0
            end
            SetAutoMode(FFX.trn, LBX_FX_TRACK_AM)
            update_gfx = true
            
          end
        
        elseif mouse.context == nil and MOUSE_click(obj.sections[8]) then
          lasttouched = nil
          chktm = reaper.time_precise()+1
          lrnmode = not lrnmode
          update_gfx = true

        elseif mouse.context == nil and MOUSE_click(obj.sections[9]) then
          
          SettingsMenu()
          
        end
     
        if mouse.context and mouse.context == contexts.sliderctl then
          local i = slider_select
          local xywh = {x = obj.sections[1].x+4,
                        y = math.floor(obj.sections[1].y + (i-1)*(fader_h+fader_space)),
                        w = obj.sections[1].w-8,
                        h = fader_h}
          local val = MOUSE_slider_horiz2(xywh,mouse.slideoff)
          if val ~= nil then
            
            if val < 0 then val = 0 end
            if val > 1 then val = 1 end
            if val ~= octlval then
              
              local track = GetTrack(FFX.trn)
              local fxnum = FFX.fxnum
              local pnum = template.pos[i].pnum
                          
              reaper.TrackFX_SetParamNormalized(track, fxnum, pnum, val)
              SetFaderBoxVal(i, val)
              template.dirty[i] = true
              octlval = val
              update_fader = true
            end
          end
        end
      
      else
        --Learn mode
        if mouse.context == nil and MOUSE_click(obj.sections[8]) then
          lrnmode = not lrnmode
          update_gfx = true
        end
      
        local retval, trn, fxn, pn = reaper.GetLastTouchedFX()
        if retval == true then
          if lasttouched == nil then
            lasttouched = {trn = trn, fxn = fxn, pn = pn}
          
          elseif (trn == FFX.trn and fxn == FFX.fxnum and pn ~= lasttouched.pn) then

            lasttouched = {trn = trn, fxn = fxn, pn = pn}

            local fnd = false
            for i = 1, control_cnt do
              if template.pos[i] and string.format('%i',template.pos[i].pnum) == string.format('%i',pn) then
                fnd = true
                break
              end
            end
            if fnd == false then
              local i = #template.pos+1
              local track = GetTrack(FFX.trn)
              local _, pname = reaper.TrackFX_GetParamName(track, FFX.fxnum, pn, '')
              SetTemplateParam(i, pn, pname)
                              
              local fxnum = FFX.fxnum
              local pnum = template.pos[i].pnum
              local val = reaper.TrackFX_GetParamNormalized(track, fxnum, pnum)
              template.pos[i].val = val
              SetFaderBoxVal(i, val)
              
              template.dirty[i] = true
              update_fader = true
            end
          end
        end
        
      end
    end  
      -------------------------------------------
      
      if not mouse.LB and not mouse.RB then mouse.context = nil end
      local char = gfx.getchar() 
      if char then 
        if char == 32 then reaper.Main_OnCommandEx(40044, 0,0) end
        if char>=0 and char~=27 then reaper.defer(run) end
      else
        reaper.defer(run)
      end
      gfx.update()
      mouse.last_LB = mouse.LB
      mouse.last_RB = mouse.RB
      mouse.last_x = mouse.mx
      mouse.last_y = mouse.my
      if mouse.LB then
        mouse.lastLBclicktime = rt
      end
      gfx.mouse_wheel = 0
      
      if refresh_gfx and mouse.context == nil and reaper.time_precise() >= refresh_gfx then
        refresh_gfx = nil
        update_gfx = true
      end
      
      for i = 1, control_cnt do
        if template.sft[i] and template.sft[i] <= reaper.time_precise() and template.eft[i] > reaper.time_precise() then
          update_fader = true
          break
        end
      end
      --[[if sfade and sfade <= reaper.time_precise() and efade > reaper.time_precise() then
        update_fader = true
      end]]
      
    --end    
  end
  
  function quit()
  
    SaveSettings()      
    gfx.quit()
    
  end
  
  function GES(key, nilallowed)
    if nilallowed == nil then nilallowed = false end
    
    local val = reaper.GetExtState(SCRIPT,key)
    if nilallowed then
      if val == '' then
        val = nil
      end
    end
    return val
  end
  
  function SettingsMenu()
  
    local tick = ''
    if settings.floatfxgui ~= 0 then
      tick = '!'
    end
    local mstr = tick..'Float FX GUI||>Float time ('.. settings.floatfxgui..' secs)'
    gfx.x = mouse.mx
    gfx.y = mouse.my
    local res = gfx.showmenu(mstr)
    if res > 0 then
    
      if res == 1 then
        if settings.floatfxgui == 0 then
          settings.floatfxgui = lvar.deffloattime
        else
          settings.floatfxgui = 0
        end
        
      elseif res == 2 then
        local ret, tm = reaper.GetUserInputs('Set float time (secs)',1,'Time (secs):',tostring(settings.floatfxgui))
        if ret == true then
          settings.floatfxgui = tonumber(tm)
          lvar.deffloattime = settings.floatfxgui
        end
      end
    
    end
    
  end
  
  function SaveSettings()
  
    a,x,y,w,h = gfx.dock(-1,1,1,1,1)
    if gfx1 then
      reaper.SetExtState(SCRIPT,'dock',nz(a,0),true)
      reaper.SetExtState(SCRIPT,'win_x',nz(x,0),true)
      reaper.SetExtState(SCRIPT,'win_y',nz(y,0),true)    
      reaper.SetExtState(SCRIPT,'win_w',nz(gfx1.main_w,400),true)
      reaper.SetExtState(SCRIPT,'win_h',nz(gfx1.main_h,450),true)    
    end
  
  end
  
  function LoadSettings()
  
    local x, y = GES('win_x',true), GES('win_y',true)
    local ww, wh = GES('win_w',true), GES('win_h',true)
    local d = GES('dock',true)
    if x == nil then x = 0 end
    if y == nil then y = 0 end
    if d == nil then d = gfx.dock(-1) end    
    if ww ~= nil and wh ~= nil then
      gfx1 = {main_w = tonumber(ww),
              main_h = tonumber(wh)}
      gfx.init("SRD SMART CONTROL", gfx1.main_w, gfx1.main_h, 0, x, y)
      gfx.dock(d)
    else
      gfx1 = {main_w = 400, main_h = 450}
      Lokasenna_Window_At_Center(gfx1.main_w,gfx1.main_h)  
    end
    
  end
  
  ------------------------------------------------------------
  
  SCRIPT='LBX_SK'
  LBX_CTL_TRNAME='__LBX_SKCTL'
  LBX_CTL_TRACK_AM = 4
  LBX_FX_TRACK_AM = 0
  LBX_FX_TRACK_DEFAM = 0
  
  flashctl = {}
  fader_touch = {}
  
  settings.hidectltrack = true
  settings.floatfxgui = 0

  control_cnt = 32
  
  local track = GetCTLTrack()
  ctltrchecktime = reaper.time_precise()
  
  --[[if setting_hidectltrack == true and track then
    reaper.SetMediaTrackInfo_Value(track, "B_SHOWINTCP", 0)
    reaper.SetMediaTrackInfo_Value(track, "B_SHOWINMIXER", 0)
    reaper.TrackList_AdjustWindows(false)
    reaper.UpdateArrange()
  end]]
  
  recmode = 0
  lrnmode = false
  
  paths.resource_path = reaper.GetResourcePath().."/Scripts/LBX/LBXSK_resources/"
  paths.template_path = paths.resource_path.."templates/"
  
  reaper.RecursiveCreateDirectory(paths.resource_path,1)
  reaper.RecursiveCreateDirectory(paths.template_path,1)
    
  control_offs = 0
  control_max = 512
  
  fadedel_s = 0.2
  fadedel_e = fadedel_s + 0.4
  
  FFX = nil
  template = {dirty = {},
              pos = {},
              sft = {},
              eft = {}}
  
  colours = {faderborder = '25 25 25',
             fader = '55 55 55',
             fader_inactive = '0 80 255',
             faderbg = '35 35 35',
             faderbg2 = '15 15 15',
             mainbg = '35 35 35',
             buttcol = '25 25 25',
             faderlit = '87 109 130',
             pnamelit = '107 129 150'}
  
  update_gfx = true
  resize_display = true

  --gfx1 = {main_w = 400, main_h = 450}  
  --Lokasenna_Window_At_Center(gfx1.main_w,gfx1.main_h)
  LoadSettings()
  mouse = {}
  run()
  reaper.atexit(quit)
  
  ------------------------------------------------------------
