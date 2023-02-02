#!/usr/bin/env python3

try:
   from gspread import authorize
except:
   print("import gspread.authorized failed")
   exit(1)
from oauth2client.service_account import ServiceAccountCredentials
from datetime import datetime
from sys import exit, argv
import json
from os.path import exists
import inspect

if __name__ == '__main__':

   if (len(argv) != 3):
      print(f"error: sheet update called with wrong arguments, expecting dir as arg1 and filename as arg2")
      exit(1)

   if argv[2] != "score_update.json":
      print(f"skipping file: {argv[2]}")
      exit(0)

   score_filepath = f"{argv[1]}/{argv[2]}"
   if not exists(score_filepath):
      print(f"error: {score_filepath} does not exist")
      exit(1)

   shell_rc = 1

   config_filepath= "/home/pi/boomer/this_boomers_data"
   sheet_name_config_filename = f"{config_filepath}/score_update_config.json"
   if not exists(sheet_name_config_filename):
      print(f"error: {sheet_name_config_filename} does not exist")
      exit(1)

   try:
      with open(sheet_name_config_filename) as infile:
         dict = json.loads(infile.readline())
         # print(f"score={row}")
   except Exception as e: 
      print(f"error: {sheet_name_config_filename} has an invalid json format: {e} - couldn't get sheet name")
      exit(1)

   sheet_name_key = "score_update_sheet_name"
   if sheet_name_key in dict:
      google_sheet_filename = dict[sheet_name_key]
      # print(f'Google Sheet Name={google_sheet_filename}')
   else:
      print(f"error: {sheet_name_config_filename} didn't contain {sheet_name_key}")
      exit(1)

   credentials_filename_key = "credentials_filename"
   if credentials_filename_key in dict:
      credentials_filename = dict[credentials_filename_key]
   else:
      print(f"error: {sheet_name_config_filename} didn't contain {credentials_filename_key}")
      exit(1)

   # the following is for sheet not found exception testing
   # google_sheet_filename = "foo"

   try:
      with open(score_filepath) as infile:
         row = json.loads(infile.readline())
         # print(f"score={row}")
   except Exception as e: 
      print(f"error: {score_filepath} has an invalid json format: {e} - not updating sheet")
      exit(1)

   if (row[0] == 'drill'):
      sheet_name = 'drills'
   elif (row[0] == 'game'):
      sheet_name = 'games'
   else:
      print(f"Invalid {score_filepath} line 1: {row}")
      exit(1)

   dt = datetime.now()
   dt_date = dt.strftime("%Y-%m-%d")
   dt_time = dt.strftime("%H:%M")

   row[0] = dt_time
   row.insert(0, dt_date)
   #Date,Time,Drill,Drill#,Duration,NumberOfBalls,Average_Score,Average_Speed
   values = [row] # values can have multiple rows
   # print(f"values={values}")

   scopes = [
   'https://www.googleapis.com/auth/spreadsheets',
   'https://www.googleapis.com/auth/drive'
   ]
   # the keys are in a locally stored file
   # credentials_filename = f"{config_filepath}/write-drill-scores-tappan-280027e40360.json"
   credentials_filepath = f"{config_filepath}/{credentials_filename}"
   try:
      credentials = ServiceAccountCredentials.from_json_keyfile_name(credentials_filepath, scopes)
   except Exception as e: 
      print(f"google credential file not found: {e}")
      exit(1)

   try:
      file = authorize(credentials)
      sheet = file.open(google_sheet_filename)
   except Exception as e: 
      # print(f"{inspect.trace()[15]}")
      for i, val in enumerate(inspect.trace()[1][4]):
         print(f"error with sheet: {val.strip()}")
      exit(1)

   try:
      sheet.values_append(sheet_name, {'valueInputOption': 'USER_ENTERED'}, {'values': values})
   except Exception as e: 
      print(f"error when appending (file opened OK): {e}")
      exit(1)
