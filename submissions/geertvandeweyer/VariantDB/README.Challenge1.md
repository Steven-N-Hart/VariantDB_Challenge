#Challenge #1. The multiple source integration problem

VariantDB is a mysql-based web & api based querying tool. Installation takes some time, so AWS images are provided. 

## Launch AWS instances



####### Get needed ip-adresses.

## Import the data

#### Load data.

Samples are loaded remotely into VariantDB. No need to download & parse locally.

```
perl scripts/Import.Data.pl -s files/Challenge_1/SampleSheet.txt -u 'http://ec2-54-221-66-111.compute-1.amazonaws.com//variantdb' -p Challenge_1 -a 5yeDJluF0kJOObbJZIKYWILhIZSaDYLJ -c 'SAVANT_EFFECT=list,SAVANT_IMPACT=list,ExAC.Info.AF=decimal'
```

##### Some  notes:
* -a : api key for variantdb. you can reset this using the web-interface to increase security.
* -c : description of fields that need to be stored next to a default set of values (GT/AD/PL/all_gatk_parameters/etc)
* The import takes about 2 hours on a 4 core SSD laptop functioning as DB & WEB host.
* Each chr-pos-ref-alt gets a unique id in the database. 
* Each variant can be assigned to a sample only once (sample-variant as unique key). Double variants are skipped, and only the first occurence is used.



#### Add population information.

```
perl scripts/Challenge_1.SetRelations.pl -u 'http://ec2-54-221-66-111.compute-1.amazonaws.com//variantdb' -a 5yeDJluF0kJOObbJZIKYWILhIZSaDYLJ -d 'files/Challenge_1'
```

##### Some  notes:
* Samples are organised into population based projects to allow filtering within one population.

#### Launch the queries

```
perl scripts/Challenge_1.Run.Query.pl -u 'http://ec2-54-221-66-111.compute-1.amazonaws.com//variantdb' -a 5yeDJluF0kJOObbJZIKYWILhIZSaDYLJ -d 'files/Challenge_1'
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
AFR": 5 
```
