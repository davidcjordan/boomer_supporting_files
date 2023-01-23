#!/usr/bin/env python3
"""
parse tcpdump output to determine if left and right cams are in-sync
by examining the frame number at a particular received timestamp
tcpdump command should be run as: sudo tcpdump -i wlan1 -x -c3 not arp | egrep "left|right|0x0010"
"""
# import datetime
import logging
import sys
log_format = ('[%(asctime)s] %(levelname)-6s %(message)s')
logging.basicConfig(format=log_format, level=logging.INFO)
logging.basicConfig(format=log_format, level=logging.DEBUG)

FRAME_DIFF_MICROS = 16667
LEFT_TO_RIGHT_DELAY_MICROS = 1000 #an estimate
FUDGE_MICROS = 2000

if __name__ == '__main__':
   line_count = 0
   timestamps = []
   cam_names = []
   frame_numbers = []
   packet_count = 0
   timestamp_diff_micros = []
   for line in sys.stdin:
      line_count += 1
      # print(f'L{line_count}: {line}')
      if line[2] == ":":
         hour = line[0:2]
         minute = line[3:5]
         second = line[6:8]
         micros = line[9:15]
         if line[19] == 'l':
            cam = 'left'
         elif line[19] == 'r':
            cam = 'right'
         else:
            cam = 'missing'
         # print(f'{line}\t{hour}:{minute}:{second}.{micros} {cam}')
         cam_names.append(cam)
         timestamps.append( (((int(hour) * 3600) + (int(minute) * 60) + int(second))*1000000) + int(micros))
      elif '0x0010' in line:
         hex_frame_number_hi= line[42:44]
         hex_frame_number_lo= line[45:47]
         frame_numbr = (256 * int(hex_frame_number_hi, 16)) + int(hex_frame_number_lo, 16)
         # print(f'{line}:\t{hex_frame_number_hi}_{hex_frame_number_lo} -> {frame_numbr}')
         frame_numbers.append(frame_numbr)
         packet_count += 1

   for i in range(3):
      print(f'{timestamps[i]} frame={frame_numbers[i]} {cam_names[i]}')

   timestamp_diff_micros.append(timestamps[1] - timestamps[0])
   timestamp_diff_micros.append(timestamps[2] - timestamps[1])
   if (timestamp_diff_micros[0] < (LEFT_TO_RIGHT_DELAY_MICROS + FUDGE_MICROS )):
      pkt_index = 0 #0 and 1 occurred on the same strobe
   else:
      pkt_index = 1 #1 and 2 occurred on the same strobe

   return_code = 2
   if (cam_names[pkt_index] == cam_names[pkt_index+1]):
      print(f"Error: first & second timestamps are from the same camera={cam_names[pkt_index]}")
   elif (pkt_index == 0) and (timestamp_diff_micros[1] < FRAME_DIFF_MICROS - FUDGE_MICROS):
         print(f"Error: the 3rd timestamp is only {timestamp_diff_micros[pkt_index+1]} micros from the 2nd")
   elif (pkt_index == 1) and (timestamp_diff_micros[0] < FRAME_DIFF_MICROS - FUDGE_MICROS):
         print(f"Error: the 1st timestamp is only {timestamp_diff_micros[pkt_index+1]} micros from the 2nd")
   elif (frame_numbers[pkt_index] != frame_numbers[pkt_index+1]):
      print(f"Cameras NOT in sync: cam={cam_names[pkt_index]}, frame={frame_numbers[pkt_index]} received 1st; {cam_names[pkt_index+1]}, frame={frame_numbers[pkt_index+1]} received {timestamp_diff_micros[pkt_index]} micros later")
      return_code = 1
   else:
      print(f"Cameras are in sync: frame={frame_numbers[pkt_index]}, cam={cam_names[pkt_index]} received 1st; {cam_names[pkt_index+1]} received {timestamp_diff_micros[pkt_index]} micros later")
      return_code = 0
   sys.exit(return_code)