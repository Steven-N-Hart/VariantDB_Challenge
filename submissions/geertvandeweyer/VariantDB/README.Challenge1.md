#Challenge #1. The multiple source integration problem

VariantDB is a mysql-based web & api based querying tool.  

## Minimal installation guidelines 

#### OS installation

Install fresh ubuntu server 14.04.5 LTS with the following settings:
	 
* CPU: At least 4 cores
* RAM: At least 16Gb
* Hard Disk : At least 75Gb
* Install ssh-server and LAMP.

Update OS & install needed packages.

```
apt-get update && apt-get upgrade
apt-get install mercurial 
```

#### Install VariantDB

Clone Installation Scripts: 

```
hg clone https://bitbucket.org/medgenua/vdb_installer
```

Install Databases using default settings: 

```
sudo ./Install_databases.sh
```

install web-interface using default settings:  

```
sudo ./Install_Web_Interface.sh
```

Set the number of threads to use to a a reasonable number (e.g. 3/4 of the cores)

```
nano /VariantDB/.Credentials/.credentials
```
=> MYSQLTHREADS=6
(here : VM has 8 CPU)

update DB settings under /etc/mysql/my.cnf

```
[mysqld]
key_buffer_size = 4048M
max_allowed_packet = 512M
thread_stack = 256K
thread_cache_size = 8
tmp_table_size = 2048M
max_heap_table_size = 2048M
bulk_insert_buffer_size = 128M
connect_timeout = 15
local_infile 
myisam_repair_threads = 4
myisam_sort_buffer_size = 4048M
open_files_limit = 8000
query_cache_limit = 12M
query_cache_size = 128M
read_buffer_size = 16M
read_rnd_buffer_size = 8M
bulk_insert_buffer_size = 256M
concurrent_insert = 2
myisam_repair_threads = 4
myisam_sort_buffer_size = 4048M
```

SKIP annotation launcher (rc.local) and PROFTPD configuration. Not needed for the challenge, since no external annotations are used. 

reboot system to make sure all changes to config are active.


#### Create a user
* Open VariantDB in a browser (http://guest_ip/variantdb
* fill in user details for admin user.
* Log in, go to user-details, activate API key (do not expire).
* write down the API_KEY.


## Install Challenge Files

Log in to the VariantDB installation. Install git and clone the repo.

```
sudo apt-get install git
git clone https://github.com/Steven-N-Hart/VariantDB_Challenge.git
cd VariantDB_Challenge/submissions/geertvandeweyer/VariantDB
```


## Import the data

#### Load data.

Samples are loaded directly into VariantDB. No need to download & parse locally.

```
perl scripts/Import.Data.pl -s files/Challenge_1/SampleSheet.txt -u 'http://127.0.01/variantdb' -p Challenge_1 -a YOUR_API_KEY -c 'SAVANT_EFFECT=list,SAVANT_IMPACT=list,ExAC.Info.AF=decimal'
```

##### Some  notes:
* -a : api key for variantdb. you can reset this using the web-interface to increase security.
* -c : description of fields that need to be stored next to a default set of values (GT/AD/PL/all_gatk_parameters/etc)
* The import takes about 2 hours on a 4 core SSD laptop functioning as DB & WEB host.
* Each chr-pos-ref-alt gets a unique id in the database. 
* Each variant can be assigned to a sample only once (sample-variant as unique key). Double variants are skipped, and only the first occurence is used.



#### Add population information.

```
perl scripts/Challenge_1.SetRelations.pl -u 'http://127.0.0.1/variantdb' -a YOUR_API_KEY -d 'files/Challenge_1'
```

##### Some  notes:
* Samples are organised into population based projects to allow filtering within one population.


#### Load The Filters for Challenge_1
Filter settings are available in json format and will be imported into your VariantDB installation.

```
python scripts/Import.Settings.py -u 'http://127.0.0.1/variantdb/api/' -k YOUR_API_KEY -I files/Challenge_1/Filter.Challenge_1.json -t f
```

#### Launch the queries

```
perl scripts/Challenge_1.Run.Query.pl -u 'http://127.0.0.1/variantdb' -a YOUR_API_KEY -d 'files/Challenge_1'
```

##### Some notes: 
* The needed filtersettings are saved in the provided image as 'Challenge_1'. They can be exported and imported (json) for use in other VariantDB instances.
* Results are returned as a json string holding {VARIANT_A:[sample1 sample2 sample3],VARIANT_B:[sample_2 sample4]} type information.
* The resulting numbers are calculated from this json structure by the script.
* Also see 'files/Challenge_1/Passed.Variants.txt' for the list of passing variants
* the file 'script/Search.Passing.Challenge_1.pl' provides a non-db-based gold-standard of the variants that should pass this challenge. 


##Result


```
EUR : 0
ASN : 3
AMR : 0
AFR : 5 
```
