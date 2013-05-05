{{
┌─────────────────────────────────────────────────┐
│ OmniVision OVM7690 CameraCube Module            │
│ Frame Grabber Cog                               │
│                                                 │
│ Author: Joe Grand                               │                     
│ Copyright (c) 2011 Grand Idea Studio, Inc.      │
│ Web: http://www.grandideastudio.com             │
│ Technical Support: support@parallax.com         │ 
│                                                 │
│ Distributed under a Creative Commons            │
│ Attribution 3.0 United States license           │
│ http://creativecommons.org/licenses/by/3.0/us/  │
└─────────────────────────────────────────────────┘

Program Description:

This cog retrieves the current frame from the
Omnivision OVM7690 CMOS CameraCube module and
stores it in the frame buffer (located in hub RAM).

It also sets a flag to a non-zero state so the
calling object knows when the frame grab is done.


Revisions:
1.0 (July 28, 2011): Initial release
 
}}

CON

  
VAR
  long Cog                      ' Used to store ID of newly started cog
  long type                     ' Frame grab type (defined in OVM7690_obj)
  long fb[g#FB_SIZE]            ' Frame buffer (in longs)
  long Done                     ' Non-zero when frame grab is complete (do not move the location of this variable)
  
  
OBJ
  g             : "LRF_con"                         ' Laser Range Finder global constants 
  'dbg           : "PASDebug"                        '<---- Add for Propeller Assembly Sourcecode Debugger (PASD), http://propeller.wikispaces.com/PASD and http://www.insonix.ch/propeller/prop_pasd.html


PUB start(t) : addr
  ' Start a new cog to run PASM routine starting at @entry
  ' Returns the address of the frame buffer (in main/hub memory) if a cog was successfully started, or 0 if error.
  Done := 0                                ' Clear flag
  stop                                     ' Call the Stop function, just in case the calling object called Start two times in a row.
  type := t 
  Cog := cognew(@entry, @type) + 1         ' Launch the cog with a pointer to the parameters
  if cog
    addr := @fb 
    
  'dbg.start(31,30,@entry)                 '<---- Add for Debugger
  

PUB stop
  ' Stop the cog we started earlier, if any
  if Cog
    cogstop(Cog~ - 1)


DAT
                        org     0
entry

'  --------- Debugger Kernel add this at Entry (Addr 0) ---------
   'long $34FC1202,$6CE81201,$83C120B,$8BC0E0A,$E87C0E03,$8BC0E0A
   'long $EC7C0E05,$A0BC1207,$5C7C0003,$5C7C0003,$7FFC,$7FF8
'  -------------------------------------------------------------- 

' Propeller @ 80MHz                              = 0.0125uS/cycle
' Propeller @ 96MHz (overclocked, 6MHz XTAL)     = 0.01042uS/cycle
' Propeller @ 100MHz (overclocked, 6.25MHz XTAL) = 0.01uS/cycle

' Timing partially defined in Section 6.1, OV7690 CSP3 Data Sheet rev. 2.11

' 176x144 (QCIF) @ 3.75fps (3MHz PCLK)
' ------------------------------------                         @ 80MHz     /    @96MHz      /   @ 100MHz
' VSYNC width                                   = 2.08mS   = 166400 cycles / 199616 cycles  / 208000 cycles
' Time from VSYNC low to HREF high              = 12.36mS  = 988800 cycles / 1186180 cycles / 1236000 cycles
' Time in between lines/HREF                    = 920uS    = 73600 cycles  / 88291 cycles   / 92000 cycles
' Time from last HREF in frame to next VSYNC    = 4.14mS   = 331200 cycles / 397312 cycles  / 414000 cycles
' Pixel clock (PCLK)                            = 0.333uS  = 26 cycles/bit / 31 cycles/bit  / 33 cycles/bit
'                                                            (must grab data within 13/15/16 cycles of PCLK going high)

' 640x480 (VGA) @ 3.75fps (3MHz PCLK)
' ------------------------------------                         @ 80MHz     /    @96MHz      /   @ 100MHz
' VSYNC width                                   = 2.08mS   = 166400 cycles / 199616 cycles  / 208000 cycles
' Time from VSYNC low to HREF high              = 10.48mS  = 838400 cycles / 1005758 cycles / 1048000 cycles
' Time in between lines/HREF                    = 93uS     = 7440 cycles   / 8925 cycles    / 9300 cycles
' Time from last HREF in frame to next VSYNC    = 4.14mS   = 331200 cycles / 397312 cycles  / 414000 cycles
' Pixel clock (PCLK)                            = 0.333uS  = 26 cycles/bit / 31 cycles/bit  / 33 cycles/bit
'                                                            (must grab data within 13/15/16 cycles of PCLK going high)

' 176x144 (QCIF) @ 2.5fps (2MHz PCLK)
' ------------------------------------                         @ 80MHz     /    @96MHz       /   @ 100MHz
' VSYNC width                                   = 3.13mS   = 250400 cycles  / 300383 cycles  / 313000 cycles
' Time from VSYNC low to HREF high              = 18.6mS   = 1488000 cycles / 1785028 cycles / 1860000 cycles
' Time in between lines/HREF                    = 1.38mS   = 110400 cycles  / 132437 cycles  / 138000 cycles 
' Time from last HREF in frame to next VSYNC    = 6.22mS   = 497600 cycles  / 596928 cycles  / 622000 cycles
' Pixel clock (PCLK)                            = 0.500uS  = 40 cycles/bit  / 48 cycles/bit  / 50 cycles/bit
'                                                            (must grab data within 20/24/25 cycles of PCLK going high)

' 640x480 (VGA) @ 2.5fps (2MHz PCLK)
' ------------------------------------                         @ 80MHz     /    @96MHz       /   @ 100MHz
' VSYNC width                                   = 3.13mS   = 250400 cycles  / 300383 cycles  / 313000 cycles
' Time from VSYNC low to HREF high              = 15.73mS  = 1258400 cycles / 1509596 cycles / 1573000 cycles
' Time in between lines/HREF                    = 140uS    = 11200 cycles   / 13435 cycles   / 14000 cycles 
' Time from last HREF in frame to next VSYNC    = 6.22mS   = 497600 cycles  / 596928 cycles  / 622000 cycles
' Pixel clock (PCLK)                            = 0.500uS  = 40 cycles/bit  / 48 cycles/bit  / 50 cycles/bit
'                                                            (must grab data within 20/24/25 cycles of PCLK going high)

:init                   mov     dira, PINS              ' Configure I/O pins
                        mov     fbAddr, par             ' Copy PAR ($1F0) to fbAddr
                        rdlong  _type, fbAddr           ' The 1st parameter is the frame grab type
                        add     fbAddr, #4              ' The 2nd parameter is a pointer to the beginning of the frame buffer
                        andn    outa, pLaserEn          ' Laser diode OFF
                        cmp     _type, #0          wz   ' Check frame grab type
              if_nz     jmp     #:get_frame_color 
:get_frame_grey                                         ' GREYSCALE FRAME, 8 bits/pixel
                        call    #wait_vsync_h           ' when VSYNC goes HIGH, indicates the start of a new frame
                        mov     cntY, _fbGryY           ' Load counter variable with number of lines in frame   
:get_line_grey               
                        call    #wait_href_l            ' Wait for HREF to be LOW
                        call    #wait_href_h            ' When HREF is HIGH, indicates the start of a new line

                        mov     cntX, _fbGryX           ' Load counter variable with number of pixels per line 
:get_pixel_grey              
' Read every pixel (16 bits each)
' PCLK is asserted (HIGH) when there is valid pixel data on the bus
' 8 bits (D7..D0) are transferred at a time, so two PCLKs are needed for each 16-bit pixel
'
'       Timing diagram @ 96MHz Propeller
'              48 cycles/bit
'       Data valid when PCLK is HIGH
'
'           Y      U/V      Y  ...
'         
'                     
'       t=0   24  48  72  96
'      cycles

:wait_pclk_h_grey       mov     regA, ina               ' Get value of port A                           4 [4]
                        and     regA, pCamPCLK     wz   ' Look at PCLK pin only                         4 [8]
              if_z      jmp     #:wait_pclk_h_grey      ' if PCLK is LOW, check again until it's HIGH   4 [12]                                  
                        mov     regA, ina               ' Get value of port A                           4 [16]  ' Data grabbed within 24 cycles @ 2MHz PCLK, OK
                        wrbyte  regA, fbAddr            ' Write LSB byte into frame buffer (Y)          22 (worst case) [38]
                        add     fbAddr, #1              ' Point at next byte in frame buffer            4 [42]  ' Finished in time for PCLK to go high again with next pixel data

                        ' Right now, we only care about the first 8 bits (Y, luma), so ignore the next 8 bits of the pixel (U/V, chroma)
                        ' Add delay to ensure that PCLK gets to the HIGH state                          worst case   best
                        nop                             '                                               4 [46]       [31]
                        nop                             '                                               4 [50 (2)]   [35]
                        nop                             '                                               4 [54 (6)]   [39]
                        nop                             '                                               4 [58 (10)]  [43]
                        nop                             '                                               4 [62 (14)]  [47]
                        nop                             '                                               4 [66 (18)]  [51]
                        waitpeq _null, pCamPCLK         ' Wait for PCLK to go LOW, since we don't want to grab the next pixel data before it's really time
                                                                  
                        sub     cntX, #1           wz   ' cntX--                                                          
              if_nz     jmp     #:get_pixel_grey             '
                        sub     cntY, #1           wz   ' cntY--
              if_nz     jmp     #:get_line_grey

                        jmp     #:swap_bytes            ' DONE with grabbing greyscale frame
                        
:get_frame_color                                        ' COLOR FRAME, 16 bits/pixel
                        call    #wait_vsync_h           ' when VSYNC goes HIGH, indicates the start of a new frame

                        ' skip lines until we reach the beginning of our region-of-interest (ROI)
                        mov     cntY, _fbRoiY      wz   ' cntY = ROI_Y
              if_nz     call    #wait_roi               ' if ROI_Y == 0, we don't need to skip any lines

                        mov     cntY, _fbClrY           ' Load counter variable with number of lines in frame            
:get_line_color
                        call    #wait_href_l            ' Wait for HREF to be LOW
                        call    #wait_href_h            ' When HREF is HIGH, indicates the start of a new line
                        
                        mov     cntX, _fbClrX           ' Load counter variable with number of pixels per line 
:get_pixel_color
                        ' get the first 8 bits (Y, luma)
:wait_pclk_h_color      mov     regA, ina               ' Get value of port A                           4 [4]
                        and     regA, pCamPCLK     wz   ' Look at PCLK pin only                         4 [8]
              if_z      jmp     #:wait_pclk_h_color     ' if PCLK is LOW, check again until it's HIGH   4 [12]                                  
                        mov     regA, ina               ' Get value of port A                           4 [16]  ' Data grabbed within 24 cycles @ 2MHz PCLK, OK
                        wrbyte  regA, fbAddr            ' Write LSB byte into frame buffer (Y)          22 (worst case) [38]
                        add     fbAddr, #1              ' Point at next byte in frame buffer            4 [42]  ' Finished just in time for PCLK to go high again with next pixel data

                        ' Add delay to ensure that PCLK gets to the HIGH state                          worst case   best
                        nop                             '                                               4 [46]       [31]
                        nop                             '                                               4 [50 (2)]   [35]
                        nop                             '                                               4 [54 (6)]   [39]
                        nop                             '                                               4 [58 (10)]  [43]
                        nop                             '                                               4 [62 (14)]  [47]
                        nop                             '                                               4 [66 (18)]  [51]
              
                        ' get the next 8 bits (U/V, chroma)
                        mov     regA, ina               ' Get value of port A                           4 [70]       [55]    ' Data grabbed within 24 cycles @ 2MHz PCLK, OK
                        wrbyte  regA, fbAddr            ' Write LSB byte into frame buffer (U/V)        22 (worst case) [92] [77]
                        add     fbAddr, #1              ' Point at next byte in frame buffer            4 [96] [81]          ' Finished just in time for PCLK to go high again with next pixel data
                                                                  
                        sub     cntX, #1           wz   ' cntX--                                        4 [100 (4)] [85]                 
              if_nz     jmp     #:get_pixel_color       '                                               4 [104 (8)] [89]
                        sub     cntY, #1           wz   ' cntY--
              if_nz     jmp     #:get_line_color

                        cmp     _type, #2          wz   ' Check frame grab type
              if_nz     jmp     #:swap_bytes            ' If we're just grabbing a single color frame, then we're done
                        ' Otherwise, we need to turn the laser on and grab another frame and perform background subtraction for better detection of laser spot
:get_frame_color2                                       ' COLOR FRAME, 16 bits/pixel (ignoring U/V values)
                        mov     fbAddr, par             ' Copy PAR ($1F0) to fbAddr                                   
                        add     fbAddr, #4              ' Increment by 1 long to point to the frame buffer parameter  
                        or      outa, pLaserEn          ' Laser diode ON

                        call    #wait_vsync_h           ' when VSYNC goes HIGH, indicates the start of a new frame
                                                                        
                        ' skip lines until we reach the beginning of our region-of-interest (ROI)
                        mov     cntY, _fbRoiY      wz   ' cntY = ROI_Y
              if_nz     call    #wait_roi               ' if ROI_Y == 0, we don't need to skip any lines

                        mov     cntY, _fbClrY           ' Load counter variable with number of lines in frame            
:get_line_color2
                        call    #wait_href_l            ' Wait for HREF to be LOW
                        call    #wait_href_h            ' When HREF is HIGH, indicates the start of a new line
                        
                        mov     cntX, _fbClrX           ' Load counter variable with number of pixels per line
:get_pixel_color2       
                        ' get the first 8 bits (Y, luma)
                        ' we want to reveal only those pixels that become bright between this frame and
                        ' the previously captured frame (preferably the laser spot)                        
:wait_pclk_h_color2     mov     regA, ina               ' Get value of port A                           4 [4]
                        and     regA, pCamPCLK     wz   ' Look at PCLK pin only                         4 [8]
              if_z      jmp     #:wait_pclk_h_color2    ' if PCLK is LOW, check again until it's HIGH   4 [12]                                  
                        mov     regA, ina               ' Get value of port A                           4 [16]  ' Data grabbed within 24 cycles @ 2MHz PCLK, OK
                        and     regA, _0x000f           ' Only work with the lower 8-bits               4 [20]
                        rdbyte  ltl, fbAddr             ' Read existing byte from frame buffer          22 (worst case] [42]
                        sub     regA, ltl               ' Background subtraction to pull out the newly bright pixels  4 [46]
                        abs     ltl, regA               ' Absolute value to avoid sign issues                         4 [50]
                        wrbyte  ltl, fbAddr             ' Write LSB byte into frame buffer (Y)          22 (worst case) [72]
                        add     fbAddr, #2              ' Point at next Y byte in frame buffer (skip U/V)             4 [76] 
                        waitpeq _null, pCamPCLK         ' Wait for PCLK to go LOW, since we don't want to grab the next pixel data before it's really time
                                                
                        sub     cntX, #1           wz   ' cntX--                                                       
              if_nz     jmp     #:get_pixel_color2      '                                              
                        sub     cntY, #1           wz   ' cntY--
              if_nz     jmp     #:get_line_color2                        
                        
                        andn    outa, pLaserEn          ' Laser diode OFF
                
' at the end of each frame, we need to change the ordering of bytes within each long of the frame buffer
' e.g., from $DEAFC089 to $89C0AFDE
' this is a time consuming process, since we need to read the byte from main memory, swap it, and write it back
' we have some available time before the start of the next frame, so we'll be OK
' maybe in the future we can optimize this to swap the bytes on a per-line basis in cog ram before writing to the frame buffer
' code below from Phil Pilgrim's solution at:
' http://forums.parallax.com/showthread.php?89910-Endian-Puzzle&p=617009&viewfull=1#post617009
:swap_bytes                              
                        mov     fbAddr, par             ' Copy PAR ($1F0) to fbAddr                                   4 [4]
                        add     fbAddr, #4              ' Increment by 1 long to point to the frame buffer parameter  4 [8]
                        mov     cntX, _fbSize           '                                                             4 [12]
:endian_swap
                        rdlong  ltl, fbAddr             ' Get long from frame buffer                    22 (worst case) [22]
                        mov     big, ltl                '\                                              4 [26]
                        and     big, _0xf0f0            '|                                              4 [30]
                        xor     ltl, big                '|  Swap routine                                4 [34]
                        rol     big, #8                 '|                                              4 [38]
                        ror     ltl, #8                 '|                                              4 [42]
                        or      big, ltl                '/                                              4 [46]
                        wrlong  big, fbAddr             ' Write swapped long back into frame buffer     22 (worst case) [68]
                        add     fbAddr, #4              ' Point to next long in frame buffer            4 [72]
                        
                        sub     cntX, #1           wz   ' cntX--                                        4 [76]
              if_nz     jmp     #:endian_swap           '                                               4 [80]
                                                        '                                Total cycles = 8 + (80 * _fbSize) = 8 + (80 * 5280) = 422408 cycles = 4.4mS @ 96MHz Propeller, OK
                        cogid   ltl                     ' Get our cog ID
                        wrlong  ltl, fbAddr             ' Write flag to Done variable to indicate frame grab is complete
                        cogstop ltl                     ' Stop the cog
                        ' SINCE THE COG HAS STOPPED, THE PROGRAM ENDS HERE


' SUBROUTINES
                        
wait_vsync_h            mov     regA, ina               ' Get value of port A                           4 [4]
                        and     regA, pCamVSYNC    wz   ' Look at VSYNC pin only                        4 [8]
              if_z      jmp     #wait_vsync_h           ' if VSYNC is LOW, check again until HIGH       4 [12]
wait_vsync_h_ret        ret                             '                                               4 [16]              


wait_href_l             mov     regA, ina               ' Get value of port A                           4 [4]
                        and     regA, pCamHREF     wz   ' Look at HREF pin only                         4 [8]
              if_nz     jmp     #wait_href_l            ' if HREF is HIGH, check again until it's LOW   4 [12]
wait_href_l_ret         ret                             '                                               4 [16]  

        
wait_href_h             mov     regA, ina               ' Get value of port A                           4 [4]
                        and     regA, pCamHREF     wz   ' Look at HREF pin only                         4 [8]
              if_z      jmp     #wait_href_h            ' if HREF is LOW, check again until it's HIGH   4 [12]
wait_href_h_ret         ret                             '                                               4 [16] 


wait_roi                sub     cntY, #1                ' cntY = cntY - 1
                        waitpeq _null, pCamHREF         ' Wait for HREF to go LOW
                        waitpne _null, pCamHREF         ' Wait for HREF to go HIGH
                        sub     cntY, #1           wz   ' cntY--   
              if_nz     jmp     #wait_roi        
wait_roi_ret            ret



' CONSTANTS
_null                   long    0
PINS                    long    %00000000_00000000_10000000_00000000     ' Pin I/O configuration, all inputs (for this cog) except P15
pLaserEn                long    %00000000_00000000_10000000_00000000     ' Mask: P15
pCamPCLK                long    %00000000_00000000_00100000_00000000     ' Mask: P13 
pCamVSYNC               long    %00000000_00000000_00010000_00000000     ' Mask: P12
pCamHREF                long    %00000000_00000000_00001000_00000000     ' Mask: P11
pCamDATA                long    %00000000_00000000_00000000_11111111     ' Mask: P7..0 (D7..D0) (MSB..LSB)
_fbSize                 long    g#FB_SIZE
_fbGryX                 long    g#FB_GRY_X
_fbGryY                 long    g#FB_GRY_Y
_fbClrX                 long    g#FB_CLR_X
_fbClrY                 long    g#FB_CLR_Y
_fbRoiY                 long    g#ROI_Y
_0xf0f0                 long    $FF00FF00
_0x000f                 long    $000000FF

' VARIABLES stored in cog RAM (uninitialized)
_type                   res     1                       ' Frame type    
fbAddr                  res     1                       ' Address of hub RAM's frame buffer (passed from calling object in Start method)
regA                    res     1                       ' Value of Register A
cntY                    res     1                       ' Line count of the current frame
cntX                    res     1                       ' Pixel count of the current line
ltl                     res     1                       ' Temporary variables for endian-swap
big                     res     1

                        fit   ' make sure all instructions/data fit within the cog's RAM
                          