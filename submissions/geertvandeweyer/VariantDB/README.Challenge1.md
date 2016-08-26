#Challenge #1. The multiple source integration problem

VariantDB is a mysql-based web & api based querying tool. Installation takes some time, so AWS images are provided. 

## Launch AWS instances

Launch the following community AMIs into the same (subnet setting, e.g. both in us-east-1b), using r3.xlarge (4CPU, 30Gb RAM) for both.: 
* VariantDB_Challenge_vdb_web - ami-1b8cee0c
* VariantDB_Challenge_vdb_db - ami-268cee31

Add both instances to a security group with the following permissions:
* inbound: SSH from 'My IP'.
* inbound: http from 'Anywhere'.
* inbound: MYSQL from 'Anywhere' 
* outbound: All Traffic to 'Anywhere'


NOTE: I know that mysql from anywhere is not optimal, but I had issues setting up the security groups. Any help/suggestions here on how to keep static (private) ips between groups of instances would be very welcome :-)


####### Get needed ip-adresses.

Identify images under 'description' using 'AMI ID'. 


* Write down the public IP of the database image (identify under 'description' using 'AMI ID'. The field you need is 'Public DNS')
* Write down the public IP and DNS of the web image.

####### Log into the WebServer to configure database connection.

Using SSH, do the following
* log in to the instance.
* set the ip of the database server in the VarianDB config file.
```
ssh -i /path/to/your/pem_file ubuntu@public_dns_of_web
sudo vim /VariantDB/.Credentials/.credentials
```

* Set DBHOST to the correct IP adress.

* log out.

 
####### Credentials for the web interfaces.

The following credentials can be used to explore the user interface:
* URL : http://public_dns_of_web_instance/variantdb
* USER : variantdb@challenge.com
* PASS : 698oodKpOy

The following credentials can be used to explore the database using phpmyadmin
* URL : http://ip_of_database_instance/phpmyadmin
* USER : root
* PASS : taootU32NG


## Import the data

#### Load data.

Samples are loaded remotely into VariantDB. No need to download & parse locally.

```
perl scripts/Import.Data.pl -s files/Challenge_1/SampleSheet.txt -u 'http://web_dns/variantdb' -p Challenge_1 -a 5yeDJluF0kJOObbJZIKYWILhIZSaDYLJ -c 'SAVANT_EFFECT=list,SAVANT_IMPACT=list,ExAC.Info.AF=decimal'
```

##### Some  notes:
* -a : api key for variantdb. you can reset this using the web-interface to increase security.
* -c : description of fields that need to be stored next to a default set of values (GT/AD/PL/all_gatk_parameters/etc)
* The import takes about 2 hours on a 4 core SSD laptop functioning as DB & WEB host.
* Each chr-pos-ref-alt gets a unique id in the database. 
* Each variant can be assigned to a sample only once (sample-variant as unique key). Double variants are skipped, and only the first occurence is used.



#### Add population information.

```
perl scripts/Challenge_1.SetRelations.pl -u 'http://web_dns/variantdb' -a 5yeDJluF0kJOObbJZIKYWILhIZSaDYLJ -d 'files/Challenge_1'
```

##### Some  notes:
* Samples are organised into population based projects to allow filtering within one population.

#### Launch the queries

```
perl scripts/Challenge_1.Run.Query.pl -u 'http://web_dns/variantdb' -a 5yeDJluF0kJOObbJZIKYWILhIZSaDYLJ -d 'files/Challenge_1'
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
