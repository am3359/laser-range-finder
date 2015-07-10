{{
┌─────────────────────────────────────────────────┐
│ Parallax Laser Range Finder                     │
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

This design uses an Omnivision OVM7690 640x480 CMOS CameraCube module and a laser diode to create a low-cost laser range finder.
Distance to a targeted object is calculated using triangulation by simple trigonometry between the centroid of laser light,
camera, and object. 

The project's theory is based on the Webcam Based DIY Laser Rangefinder:
http://sites.google.com/site/todddanko/home/webcam_laser_ranger

Refer to the User's Manual and the "Laser Range Finder Development Diary" thread on the Parallax Forums for more details:
http://forums.parallax.com/showthread.php?t=126496

Huge thanks to Zoz, Roy Eltham, and #tymkrs for image processing and optimization contributions, without which this project
would have never been completed!

Command listing is available in the DAT section at the end of this file.
 
}}


CON
  _clkmode = xtal1 + pll16x
  _xinfreq = 6_000_000            ' 96MHz overclock
  _stack   = 50                   ' Ensure we have this minimum stack space available

  ' I/O pin connections to the Propeller
  LaserEnPin    = 15              ' APCD laser diode module (active HIGH) (also defined in OVM7690_fg)
  LedRedPin     = 24              ' Bi-color Red/Green LED, common cathode
  LedGrnPin     = 25

  SerRxPin      = 27              ' Serial interface, IN from user
  SerTxPin      = 26              '                   OUT to user
    
  'SerRxPin      = 31              ' Serial interface via Prop Clip/Plug, IN from user
  'SerTxPin      = 30              '                                      OUT to user
  
  ' Serial terminal
  ' Control characters
  NL = 13  ''NL: New Line        
  CS = 16  ''CS: Clear Screen

  eepromAddress   = $8000       ' Starting address within EEPROM for LRF configuration values

  
VAR
  long fbPtr                    ' Pointer to frame buffer (defined in OVM7690_fg)                                                      
  byte roi[g#ROI_X]             ' Sum of detected pixels per column within our ROI
  byte num_blobs                ' Number of detected blobs (0 = none)    
  word blob[g#MAX_BLOBS * 4]    ' Array containing up to MAX_BLOBS number of blob details
  word weighted_sums[g#MAX_BLOBS]

  ' Range finding
  long slope                    ' Used by LRFCalculateDistance to convert pixel offset to angle using a best-fit slope-intercept linear equation
  long intercept
  long pfc_min                  ' Minimum allowable pixels_from_center value (corresponds to the maximum allowable range)

  ' Baud rate detection variables
  long BaudRate
  long bBaudAutoDetected        ' Flag set when baud auto-detected
  
     
OBJ
  g             : "LRF_con"                             ' Laser Range Finder global constants  
  cam           : "OVM7690_obj"                         ' OVM7690 CMOS camera
  ser           : "JDCogSerial"                         ' Full-duplex serial communication (Carl Jacobs, http://obex.parallax.com/objects/398/)
  f             : "F32"                                 ' IEEE 754 compliant 32-bit floating point math routines (Jonathan "lonesock" Dummer, http://obex.parallax.com/objects/689/)
  fp            : "FloatString_Lite"                    ' IEEE 754 compliant 32-bit floating point-to-string conversions (included w/ Parallax Propeller Tool, modified to remove unused code)
  eeprom        : "Basic_I2C_Driver"                    ' I2C protocol for boot EEPROM communication (Michael Green, http://obex.parallax.com/objects/26/)

  
PUB main | cmd, data1, data2
  SystemInit
           
  cam.setPCLK(2)                         ' set PCLK to 8MHz (10fps)
        
  ' Start command receive/process cycle
  repeat
    LEDGreen                    ' Set status indicator to show that we're ready
    LaserOff                    ' Ensure laser is off when not in use
    ser.Tx(NL)
    ser.Tx(":")                 ' Print command prompt
    cmd := ser.Rx               ' Wait here to receive a byte
    LEDRed                      ' Set status indicator to show that we're processing a command
    case cmd
      "G", "g":                 ' Capture & send single frame (8 bits/pixel greyscale)
        cam.setRes(g#GRY_X, g#GRY_Y)           ' Configure camera for lower resolution      
        fbPtr := cam.getFrame(cam#GreySingle)  ' Get frame
        cam.setRes(g#CLR_X, g#CLR_Y)           ' Set resolution back to default     
        DumpFrame                              ' Dump frame contents (in binary) to serial port

      "C", "c":                 ' Capture & send single frame (16 bits/pixel YUV422 color) w/ laser enabled
        LaserOn
        fbPtr := cam.getFrame(cam#ColorSingle)    
        LaserOff
        DumpFrame 
    
      "P", "p":                 ' Capture & send processed frame (16 bits/pixel YUV422 color)
        fbPtr := cam.getFrame(cam#ColorRange)
        DumpFrameP 
  
      "R", "r":                 ' Single range measurement
        LRFDisplayRange(LRFGetRange, cam#ResultASCII)

      "B", "b":                 ' Single range measurement (binary response, 4 bytes, MSB first)
        LRFDisplayRange(LRFGetRange, cam#ResultBinary)
      
      "L", "l":                 ' Repeated range measurement (any received byte will stop the loop)
        repeat until (ser.RxCheck > -1)
          LRFDisplayRange(LRFGetRange, cam#ResultASCII)

      "O", "o":                 ' Display coordinate, mass, and centroid information for all detected blobs
        LRFBlobDisplay
        
      "E", "e":                 ' Calibrate camera for current environment
        if cam.calibrate        
          ser.Str(String(NL, "ERR: cam.calibrate"))
          Error
          
      "S", "s":                 ' Reset camera to initial settings
        if cam.init             ' Initialize OVM7690 CMOS camera 
          ser.Str(String(NL, "ERR: cam.init"))
          Error
    
        if cam.setRes(g#CLR_X, g#CLR_Y)  ' Set default resolution for Laser Range Finding functionality
          ser.Str(String(NL, "ERR: cam.setRes"))
          Error

        cam.setPCLK(2)          ' set PCLK to 8MHz (10fps)
         
      
      "V", "v":                 ' Print version information
        ser.Str(@InitHeader)                  ' Start-up header; uses string in DAT section.
         
        if cam.getID(@data1, @data2)          ' Read manufacturer and product IDs
          ser.Str(String(NL, "ERR: cam.getID"))  
          Error
        ser.Str(String("MFG = "))         ' OmniVision = 0x7FA2
        ser.Hex(data1, 4)
        ser.Str(String(NL, "PID = "))  ' CameraCube OVM06790-R20A = 0x7691
        ser.Hex(data2, 4)

        LRFDisplayCalibration(slope, intercept, pfc_min)   ' Display configuration values
        
      "X", "x":                 ' Calibrate camera system for range finding (requires user interaction)
        LRFCalibrate
      
      "H", "h":                 ' Print list of available commands
        ser.Str(@CommandList)   ' Uses string in DAT section.
                
      other:                    ' Unknown command    
        ser.Tx("?")


PRI LRFCalibrate : err | ackbit, centroid, distance, ipt, x_pfc, y_angle, sumx, sumy, sumxx, sumxy, xavg, yavg, slope_new, intercept_new, pfc_min_new   ' Calibrate camera system for range finding (requires user interaction)
  ' SLOPE, INTERCEPT, and PFC_MIN values are specific for each unit based on manufacturing & assembly tolerances.
  ' We calculate them here by taking a number of measurements at known distances (routine based lightly on
  ' http://www.eng.umd.edu/~nsw/ench250/slope.htm). The results are stored in the non-volatile boot Serial EEPROM.
  '
  ' The values are used by LRFCalculateDistance to convert pixel offset to angle using a best-fit slope-intercept
  ' linear equation. It is crucial that the calibration is done properly in order to obtain the best accuracy/
  ' reliability of range calculations. Calibration distances are to be measured from the target object to the
  ' front face of the PCB.   
  '
  ' The LRF's EEPROM (64KB) is larger than required by the Propeller, so there is 32KB of additional, unused
  ' area available for data storage. This also means that the values will not get over-written when the LRF
  ' code is re-loaded into the EEPROM.

  ser.Str(String(NL, "Are you sure you want to calibrate (Y/N)?"))
  repeat
    ipt := ser.Rx
    case ipt
      "Y", "y":
        quit
      "N", "n":
        ser.Str(String(NL, "Calibration aborted!"))
        return -1
 
  ' clear counters
  sumx := 0
  sumxx := 0
  sumy := 0
  sumxy := 0
  ipt := 0
   
  repeat distance from g#CAL_MIN_DISTANCE to g#CAL_MAX_DISTANCE step g#CAL_STEP        ' At each distance, get the pfc and angle
    ser.Str(String(NL, "Set LRF to D = "))
    ser.Dec(distance)
    ser.Str(String(" cm and press spacebar (any other key to abort)"))
    ser.RxFlush                                         ' Clear receive buffer to prevent starting calibration unintentionally 
    if (ser.Rx <> " ")                                  ' Wait here to receive a byte
      ser.Str(String(NL, "Calibration aborted!"))         ' Abort if not spacebar
      return -1
        
    repeat g#CAL_NUM_PER_DISTANCE               ' Take a number of measurements at each distance for more accurate results
      fbPtr := cam.getFrame(cam#ColorRange)       ' Get processed frame (16 bits/pixel YUV422 color) 
      centroid := LRFBlobDetection                ' Locate blob(s) within the frame 
      if (centroid == 0)                          ' If the primary blob has not been detected...
        ser.Str(String(NL, "Blob not detected. Calibration failed!"))
        return -1
      else                                        ' Otherwise, let's perform the required calculations
        ipt += 1                                  ' Increment counter for the number of measurements taken
        x_pfc := ||(g#CLR_X_CENTER - centroid)    ' Number of pixels from center of frame
        ser.Str(String(NL, "pfc: "))
        ser.Dec(x_pfc)
            
        ' angle = arctan(h / distance)
        y_angle := f.ATan2(g#LRF_H_CM, f.FFloat(distance))  ' Angle (in radians)
        ser.Str(String(" angle: "))
        ser.Str(fp.FloatToString(y_angle))
               
        ' Find the various sums needed for calculating SLOPE and INTERCEPT
        sumx += x_pfc
        sumxx += (x_pfc * x_pfc)
        sumy := f.FAdd(sumy, y_angle)
        sumxy := f.FAdd(sumxy, f.FMul(f.FFloat(x_pfc), y_angle))
    ser.Tx(NL)

  ' if we get here, that means we have valid data...   
  ' Find the averages of the values
  xavg := f.FDiv(f.FFloat(sumx), f.FFloat(ipt))
  yavg := f.FDiv(sumy, f.FFloat(ipt))

  ' display intermediary results
  {ser.Str(String(NL, "sumx: "))
  ser.Dec(sumx)
  ser.Str(String(" xavg: "))
  ser.Str(fp.FloatToString(xavg))
  ser.Str(String(" sumxx: "))
  ser.Dec(sumxx)
  ser.Str(String(NL, "sumy: "))
  ser.Str(fp.FloatToString(sumy))
  ser.Str(String(" yavg: "))
  ser.Str(fp.FloatToString(yavg))
  ser.Str(String(" sumxy: "))
  ser.Str(fp.FloatToString(sumxy))}
    
  ' Find the SLOPE and INTERCEPT
  ' slope = (sumxy - sumx*yavg) / (sumxx - sumx*xavg)
  ' intercept = yavg - slope*xavg
  slope_new := f.FDiv(f.FSub(sumxy, f.FMul(f.FFloat(sumx), yavg)), f.FSub(f.FFloat(sumxx), f.FMul(f.FFloat(sumx), xavg)))
  intercept_new := f.FSub(yavg, f.FMul(slope_new, xavg)) 
 
  ' calculate PFC_MIN, which is the minimum allowable pixels_from_center value (and corresponds to the maximum allowable range)
  ' it is based on the INTERCEPT and SLOPE values specific to the unit and only needs to be re-calculated when they change
  ' pfc_min = (ANGLE_MIN - intercept) / slope
  pfc_min_new := f.FRound(f.FDiv(f.FSub(g#ANGLE_MIN, intercept_new), slope_new))

  ' display new values  
  LRFDisplayCalibration(slope_new, intercept_new, pfc_min_new)
  
  ser.Str(String(NL, NL, "Write new values (Y/N)?"))
  repeat
    ipt := ser.Rx
    case ipt
      "Y", "y":
        quit
      "N", "n":
        ser.Str(String(NL, "Calibration aborted!"))
        return -1

  slope := slope_new
  intercept := intercept_new
  pfc_min := pfc_min_new      
  
  ' write new values into the EEPROM (overwriting old values)
  ackbit := 0
  ackbit += writeLong(eepromAddress, slope)  
  ackbit += writeLong(eepromAddress + 4, intercept)
  ackbit += writeLong(eepromAddress +8, pfc_min)
  if ackbit
    ser.Str(String(NL, "ERR: eeprom.WriteLong"))  
    Error

  return 0
  

PRI LRFDisplayCalibration(xslope, xintercept, xpfc_min)
  fp.SetPositiveChr("+")              ' Set lead character for positive numbers
  
  ser.Str(String(NL, "SLOPE = "))
  ser.Str(fp.FloatToString(xslope))             ' Display SLOPE in floating point and hex
  ser.Str(String(" ("))
  ser.Hex(xslope, 8)
  ser.Str(String(")", NL, "INT = "))
  ser.Str(fp.FloatToString(xintercept))         ' Display INTERCEPT in floating point and hex
  ser.Str(String(" ("))  
  ser.Hex(xintercept, 8)   
  ser.Str(String(")", NL, "PFC_MIN = "))
  ser.Dec(xpfc_min)                             ' Display PFC_MIN in decimal
  
  fp.SetPositiveChr(0)                ' Reset to default

     
PRI LRFGetRange : range | centroid     ' Single range measurement
' range = distance from LRF module to target object
' centroid = X coordinate of the primary blob's centroid 
  
  fbPtr := cam.getFrame(cam#ColorRange)       ' Get processed frame (16 bits/pixel YUV422 color) 

  centroid := LRFBlobDetection                ' Locate blob(s) within the frame 
  if (centroid <> 0)                          ' If the primary blob has been detected...
    range := LRFCalculateDistance(centroid)   ' ...then calculate the distance!

    if (range == 0)
      range := f.FFloat(999)    
    ' range is returned from LRFCalcuateDistance in centimeters
    ' convert to millimeters, since it's easier to send a process a whole number (instead of having a decimal point as with cm)
    range := f.FRound(f.FMul(range, constant(10.0)))
  else
    range := 0                                ' If no blobs were detected, then make sure range is 0

  return range

  
PRI LRFDisplayRange(range, type)      ' Print the range result

  if (type == cam#ResultBinary)  ' Send 4-byte long in binary corresponding to the actual range value
    ser.Tx(range.BYTE[3])
    ser.Tx(range.BYTE[2])
    ser.Tx(range.BYTE[1])
    ser.Tx(range.BYTE[0])
  else                           ' Default to printable ASCII output
    ser.Tx(NL)
    ser.Str(String("D = "))
    ser.Tx("0" + range / 1000)                ' Add leading zeros so we always send a 4-character value
    ser.Tx("0" + (range // 1000) / 100)
    ser.Tx("0" + (range // 100)  / 10)
    ser.Tx("0" + (range // 10))
    ser.Str(String(" mm "))


PRI LRFBlobDisplay | ix, centroid     ' Display coordinate, mass, and centroid information for all detected blobs
  fbPtr := cam.getFrame(cam#ColorRange)       ' Get processed frame (16 bits/pixel YUV422 color) 

  centroid := LRFBlobDetection                ' Locate blob(s) within the frame   
  if (centroid <> 0)                          ' If the primary blob has been detected, then that means one or more blobs exist...
    repeat ix from 0 to (num_blobs - 1)       ' ...So, display all blob information
      ser.Tx(NL)
      ser.Dec(ix)
      ser.Str(String(": L = "))
      ser.Dec(blob[ix * 4 + g#BLOB_LEFT])
      ser.Str(String(" R = "))
      ser.Dec(blob[ix * 4 + g#BLOB_RIGHT])
      ser.Str(String(" M = "))
      ser.Dec(blob[ix * 4 + g#BLOB_MASS])
      ser.Str(String(" C = "))
      ser.Dec(blob[ix * 4 + g#BLOB_CENTROID])


PRI LRFBlobDetection : centroid | found_blob, ix, iy, val, tmp, index, found, blob_offset, blob_left   ' Locate blob(s) within the frame, returns the X coordinate of the largest mass (the primary centroid)
' found_blob = flag set while there is a blob currently being processed

  ' * THRESHOLD and COLUMN SUM *
  ' threshold each pixel based on a lower brightness bound
  ' then, keep a sum of "valid" pixels per column of the image
  ' basically creating a 1-D array/histogram, which is much easier to work with compared to a 2-D frame  
  bytefill(@roi, 0, g#ROI_X)                            ' clear array
            
  repeat iy from 0 to constant(g#FB_CLR_Y - 1)          ' for each row Y
    index := (iy * g#FB_CLR_X) << 1                       ' calculate index for the start of the line
    repeat ix from 0 to constant(g#ROI_X - 1)             ' for each column X within our region-of-interest (we only care about the left side of the frame - anything on the right is not our laser)
      if (BYTE[fbPtr][index] > g#LOWER_BOUND)               ' if pixel's Y component is above the lower brightness bound, then pixel is "valid"
        roi[ix] += 1                                        ' so, increment count for the current column
      index += 2                                            ' look at every other byte of the frame buffer (where the Y component is)
      
  {repeat ix from 0 to (g#ROI_X - 1) 
    ser.Dec(ix) ' print column sums
    ser.Str(String(": "))
    ser.Dec(roi[ix])
    ser.Tx(NL)}
    
  ' * FIND THE BLOBS *
  ' search through the 1-D array to find the blobs and determine their start and end coordinates
  ' store details in the blob[] array (there's no easy way to make a 2-D array or create a struct in Spin, so we just have to keep track of the locations within the code)
  ' we also calculate the blobs mass as we go, and track the weighted sum of all positive pixels in the blob
  num_blobs := 0
  found_blob := FALSE
  repeat ix from 0 to (g#ROI_X - 1)                     ' for each column X within our region-of-interest
    if (roi[ix] > g#SUM_THRESHOLD) AND (found_blob == FALSE)                    ' we've found the beginning of a blob
      num_blobs += 1                                    ' increment blob count
      if (num_blobs > g#MAX_BLOBS)                      ' stop searching for blobs in the frame if we've reached our limit
        num_blobs := g#MAX_BLOBS                         
        quit

      blob_offset := (num_blobs - 1) << 2
      blob_left := ix

      blob[blob_offset + g#BLOB_LEFT] := ix             ' save the location
      blob[blob_offset + g#BLOB_MASS] := roi[ix]        ' start the mass accumulation
      weighted_sums[num_blobs - 1] := roi[ix]           ' start the weighted sum
      found_blob := TRUE

    elseif (roi[ix] > g#SUM_THRESHOLD) AND (found_blob == TRUE)                 ' continuing the blob (accumulating mass and weighted sum)
      blob[blob_offset + g#BLOB_MASS] += roi[ix]
      weighted_sums[num_blobs - 1] += ((ix - blob_left) + 1) * roi[ix]
    
    elseif (roi[ix] =< g#SUM_THRESHOLD) AND (found_blob == TRUE)                ' we've found the end of the blob
      blob[blob_offset + g#BLOB_RIGHT] := ix - 1        ' save the location
      found_blob := FALSE

  if (num_blobs == 0)                                   ' if no blobs are detected, then exit
    'ser.Str(String("No blobs detected."))
    return 0
        
  else
    {ser.Str(String("Blobs detected: "))                ' if one or more blobs exist...
    ser.Dec(num_blobs)
    ser.Tx(NL)}
    
    ' calculate centroid and mass for each detected blob
    repeat ix from 0 to (num_blobs - 1)
      blob_offset := ix << 2
      blob[blob_offset + g#BLOB_CENTROID] := (weighted_sums[ix] / blob[blob_offset + g#BLOB_MASS]) + blob[blob_offset + g#BLOB_LEFT] - 1   ' calculate the true centroid (e.g., where in the blob the weight is centered)
      'blob[ix * 4 + g#BLOB_CENTROID] := ((blob[ix * 4 + g#BLOB_RIGHT] - blob[ix * 4 + g#BLOB_LEFT]) / 2) + blob[ix * 4 + g#BLOB_LEFT]     ' simpler/alternate calculation, assumes blob is well balanced (equal mass on both sides of the mean)

    ' determine the blob with the largest mass (this is likely our laser spot)
    ' if there are two blobs with the same mass, the first occurrence remains the maximum/primary
    ' the blob has to have at least a minimum threshold mass to be counted
    val := 0               ' index into the blob array pointing to the largest mass
    found := FALSE
    repeat ix from 0 to (num_blobs - 1)
      if (blob[(ix << 2) + g#BLOB_MASS] > g#BLOB_MASS_THRESHOLD)
        if (found == FALSE OR blob[(ix << 2) + g#BLOB_MASS] > blob[(val << 2) + g#BLOB_MASS])      ' if current blob has a larger mass than the current maximum...
          val := ix                                        ' ...then set it to be the new maximum   
          found := TRUE                                                     
        
    if (found == FALSE)
      return 0
      
    {ser.Str(String("Primary blob: "))
    ser.Dec(val)
    ser.Tx(NL)}

  return (blob[val * 4 + g#BLOB_CENTROID])   ' return the X coordinate of the primary centroid            

 
PRI LRFCalculateDistance(centroid) : range | pfc, angle   ' Calculate distance from LRF module to target object (based on primary centroid), returns range in cm
' pfc or pixels_from_center = number of pixels the centroid is from center of frame
' angle = angle (in radians) created by the laser, target, and camera. corresponds to pixels_from_center using slope-intercept linear equation.

  ' calculate the number of pixels from center of frame
  pfc := ||(g#CLR_X_CENTER - centroid) 
   
  if (pfc < pfc_min)                 ' if the pfc value is less than our minimum (e.g., greater than our maximum allowable distance)
    return 0                           ' then exit

  else                               ' otherwise, let's calculate the actual distance                
    ' use a best-fit slope-intercept linear equation (based on calibration measurements) to convert pixel offset (pfc) to angle
    ' angle = (slope * pfc) + intercept
    angle := f.FAdd(f.FMul(slope, f.FFloat(pfc)), intercept)
     
    ' calculate range in cm
    ' D = h / tan(theta)
    range := f.FDiv(constant(g#LRF_H_CM), f.Tan(angle))


PRI DumpFrame | index, data
  repeat index from 0 to (g#FB_SIZE - 1)  ' For each long in the buffer...
    data := LONG[fbPtr][index]
    ser.Tx(data.BYTE[3])    ' ...we need to print out each byte
    ser.Tx(data.BYTE[2])
    ser.Tx(data.BYTE[1])
    ser.Tx(data.BYTE[0])

  ser.Str(String("END"))


PRI DumpFrameP | index, data ' this variant is needed because the LRF viewer app expects the processed frame in a different byte order than it's in now
  repeat index from 0 to (g#FB_SIZE - 1)  ' For each long in the buffer...
    data := LONG[fbPtr][index]
    ser.Tx(data.BYTE[2])    ' ...we need to print out each byte
    ser.Tx(data.BYTE[3])
    ser.Tx(data.BYTE[0])
    ser.Tx(data.BYTE[1])

  ser.Str(String("END"))
       
PRI SystemInit | CommPtr, ackbit
  ' Set direction of I/O pins
  dira[LedRedPin] := 1          ' Output
  dira[LedGrnPin] := 1          ' Output
  dira[LaserEnPin] := 1         ' Output

  ' Set I/O pins to the proper initialization values
  LaserOff                      ' Ensure laser is off during power-up intialization
  LedYellow                     ' Yellow = system initialization

  f.Start                       ' Start floating point cogs (2)
  fp.SetPrecision(8)            ' Set precision of FloatToString

  AutoBaudDetect                '  Wait here until auto-baud detection is successful    
  
  CommPtr := ser.Start(|<SerRxPin, |<SerTxPin, BaudRate)  ' Start JDCogSerial cog
  if CommPtr == 0
    Error                       ' If we can't start the serial cog, then all we can do is blink
    
  ser.rxflush                   ' Flush receive buffer

  if cam.start                  ' Start OVM7690 CMOS camera 
    ser.Str(String(NL, "ERR: cam.start"))
    Error
        
  if cam.setRes(g#CLR_X, g#CLR_Y)  ' Set default resolution for Laser Range Finding functionality
    ser.Str(String(NL, "ERR: cam.setRes"))
    Error  

  ' retrieve SLOPE, INTERCEPT, and PFC_MIN values from EEPROM
  ' these values are specific for each unit based on manufacturing & assembly tolerances 
  ' they are used by LRFCalculateDistance to convert pixel offset to angle using a best-fit slope-intercept linear equation
  eeprom.Initialize(eeprom#BootPin)        ' Setup I2C

  ackbit := 0
  ackbit += readLong(eepromAddress, @slope)          ' Read current configuration values
  ackbit += readLong(eepromAddress + 4, @intercept)
  ackbit += readLong(eepromAddress + 8, @pfc_min)
  if ackbit                                          ' If there is an error reading the EEPROM...
    ser.Str(String(NL, "ERR: readLong"))               ' ...then let the user know
    Error
  if (slope == -1) OR (intercept == -1) OR (pfc_min == -1)  ' If any value is $FFFFFFFF, then the system is uncalibrated
    ser.Str(String(NL, "WARNING: LRF not calibrated!"))       ' Print a warning and continue

    
PRI Error       ' error mode. something went wrong, so stay here and flash the indicator light 
  repeat                                       
    LedOff
    waitcnt(clkfreq >> 1 + cnt)
    LedYellow
    waitcnt(clkfreq >> 1 + cnt)


PRI LaserOn
  outa[LaserEnPin] := 1


PRI LaserOff
  outa[LaserEnPin] := 0

  
PRI LedOff
  outa[LedRedPin] := 0 
  outa[LedGrnPin] := 0

  
PRI LedGreen
  outa[LedRedPin] := 0 
  outa[LedGrnPin] := 1

  
PRI LedRed
  outa[LedRedPin] := 1 
  outa[LedGrnPin] := 0

  
PRI LedYellow
  outa[LedRedPin] := 1 
  outa[LedGrnPin] := 1


PRI AutoBaudDetect : bDetected | t0, cog
' Baud rate auto-detection routines from Raymond Allen's RS232 interface for uOLED-96-Prop
' http://www.rayslogic.com/propeller/3rdPartyHardware/uOLED-96-Prop/RS232Driver.htm
'
' Modified by Joe Grand:
' - Increased maximum baud rate to 115.2kbps (using 96MHz clock)
' - Removed timeout counter
' - Calls error mode if cog can't start
'
' Upon power-up, the BaudDetect cog waits for a "U" ($55) character
' This object will wait until a valid baud rate is detected

  'Returns true when detected
  'init vars
  bBaudAutoDetected:=false
  t0:=cnt  'record start time
  
  'launch cog to wait for "U" character
  cog:=cognew(BaudDetect, @blob) ' use the blob array temporarily for the cog's stack
  if (cog == -1)  ' if there's a problem starting the cog, then all we can do is blink
    Error
    
  'monitor detection progress
  repeat
    if bBaudAutoDetected==true
      quit

  return true  

  
PRI BaudDetect | t1, t2, t3, t4, i, ClocksPerBit, mask
  'Do the detection of "U"=$55 character
  mask:=1<<SerRxPin  'generate bit mask for waitpeq command
  repeat  'can loop forever because main routine will kill this cog when it reaches timeout  
    'first wait for pin to go low     
    waitpeq(0, mask, 0)
    t1:=cnt
    'then wait to go high
    waitpeq(mask, mask, 0)
    t2:=cnt
    'wait for pin to go low
    waitpeq(0, mask, 0)
    t3:=cnt
    'wait to go high
    waitpeq(mask, mask, 0)
    t4:=cnt 
         
    'examine time differences to see if they make sense for some baud rate
    t1:=(t2-t1)
    t2:=(t3-t2)
    t3:=(t4-t3) 

    'test to make sure other values match t1
    if ((||(t1-t2))<100) and  ((||(t1-t3))<100)
      'Now, see what baud rate it is
      repeat i from 1 to 10
        BaudRate:=lookup(i: 300, 600, 1200, 2400, 4800, 9600, 19200, 38400, 57600, 115200)
        ClocksPerBit:=clkfreq/BaudRate
        if t1<(ClocksPerBit*120/100) and t1>(ClocksPerBit*80/100)
          bBaudAutoDetected:=true  'flag that baud rate found    
          return  'this will kill this cog
          

PRI readLong(addrReg, dataPtr) : ackbit
  ackbit := eeprom.ReadPage(eeprom#BootPin, eeprom#EEPROM, addrReg, dataPtr, 4)

  
PRI writeLong(addrReg, data) : ackbit | startTime 
  if eeprom.WritePage(eeprom#BootPin, eeprom#EEPROM, addrReg, @data, 4)
    return true ' an error occured during the write
    
  startTime := cnt ' prepare to check for a timeout
  repeat while eeprom.WriteWait(eeprom#BootPin, eeprom#EEPROM, addrReg)
     if cnt - startTime > clkfreq / 10
       return true ' waited more than a 1/10 second for the write to finish
    
  return false ' write completed successfully

               
DAT
InitHeader    byte NL, "Parallax Laser Range Finder", NL
              byte "Designed by Grand Idea Studio [www.grandideastudio.com]", NL
              byte "Manufactured and distributed by Parallax [support@parallax.com]", NL, NL
              byte "FW = 2.X", NL, 0

CommandList   byte NL, "Basic Commands:", NL
              byte "R   Single range measurement", NL
              byte "B   Single range measurement (binary response, 4 bytes)", NL
              byte "L   Repeated range measurement (any subsequent byte will stop the loop)", NL
              byte "E   Adjust camera for current lighting conditions", NL
              byte "S   Reset camera to initial settings", NL
              byte "V   Print version information", NL
              byte "H   Print available commands", NL
              byte NL, "Advanced Commands:", NL
              byte "O   Display coordinate, mass, and centroid information for all detected blobs", NL
              byte "X   Calibrate camera system for range finding (requires user interaction)", NL 
              byte "G   Capture & send single frame (8 bits/pixel greyscale @ 160x128)", NL
              byte "C   Capture & send single frame (16 bits/pixel YUV422 color @ 640x16) w/ laser enabled", NL
              byte "P   Capture & send processed frame (16 bits/pixel YUV422 color @ 640x16) w/ background subtraction", 0

          