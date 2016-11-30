#!/usr/bin/python
# default modules
import sys
import json
import urllib
import urllib2
import getopt 
import os.path
# non-default packages (install with "pip install ")
import requests


def main() :
	# parse commandline
	optlist,args = getArgs(sys.argv[1:])
	# if no api key provided : exit
	try: 
		apikey = optlist['k']
	except: 
		print('No API key provided.')
		Usage()
			
	# set variantdb_url
	vdb_url = optlist['u']

	# check correctness of API.
	answer = fetch_json_page(vdb_url + 'CheckApiKey?apiKey='+apikey)
	try:
		answer == '1'
	except:
		print(answer) 
		print("Invalid API Key provided.")
		print("Log in on VariantDB and check the key under User-Settings (click on you name)")
		Usage()

	# import.	
	try:
		os.path.isfile(optlist['I'])
			
	except:
		print("Provided file path does not exist")
		Usage()	
	
	# filter.
	if optlist['t'] == 'f':
		## now pass it VariantDB api.
		answer = requests.post(vdb_url+"LoadFilters?apiKey="+apikey,data={'apiKey':apikey},files={'json_file': open(optlist['I'], 'r')})
		fid = json.loads(answer.text)
		print "Filter Stored under ID: ",fid['id']

	elif optlist['t'] == 'a':
		## now pass it VariantDB api.
		answer = requests.post(vdb_url+"LoadFilters?apiKey="+apikey,data={'apiKey':apikey},files={'json_file': open(optlist['I'], 'r')})
		fid = json.loads(answer.text)
		print "Annotation Stored under ID: ",fid['id']

	else:
		print "Invalid input type. needs to be 'f' or 'a'."
		Usage()

def getArgs(args):  
	## arguments
	# -k : apikey (mandatory)
	# -I : in_file_path to import (optional)
	# -u : variantdb url.
	# -t : type : (f)ilter or (a)nnotations
	opts, args = getopt.getopt(args, 'k:t:I:hu:')
	optlist = dict()
	for opt, arg in opts:
		optlist[opt[1:]] = arg
	
	if 'h' in optlist:
		Usage()

	# mandatory options.
	if  'u' not in optlist:
		print "Missing argument : -u"
		Usage()
	if  'I' not in optlist:
		print "Missing argument : -I"
		Usage()
	if  't' not in optlist:
		print "Missing argument : -t"
		Usage()

	return(optlist,args)

def Usage():
	# print help
	print "\n\nUsage: python Import.Settings.py -k  API_KEY -u http://variant_db_server/variantdb/api/"
	print " Goal: Import a filter/annotation set into VariantDB"
	print " option: -I : File to import (json representation exported from another instance). "
	print " option: -t : type of input file : (f)ilter or (a)nnotation"
	print "\n\n"
	sys.exit(0)

def fetch_json_page(url):
    try: 
        data = urllib2.urlopen(url)
	j = json.load(data)
    except:
        print('Fetching api repsonse failed for following url:')
        print(url)
        sys.exit(2)
     
    ## return data
    return j 


if __name__ == "__main__":
	main()
