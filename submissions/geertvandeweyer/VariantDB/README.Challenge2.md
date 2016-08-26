Challenge #2. The continuous integration problem.

VariantDB is a mysql-based web & api based querying tool. Installation takes some time, so AWS images are provided. 

## Launch AWS instances

cfr README.Challenge1.md. The same instance should be used.




#### Load data.

Samples are loaded remotely into VariantDB. No need to download & parse locally.

```
perl scripts/Import.Data.pl -s files/Challenge_2/SampleSheet.txt -u 'http://ec2-54-221-66-111.compute-1.amazonaws.com//variantdb' -p Challenge_2 -a 5yeDJluF0kJOObbJZIKYWILhIZSaDYLJ
```

##### Some  notes:
* -a : api key for variantdb. you can reset this using the web-interface to increase security.
* In the samplesheet, the second to last column specifies whether or not the VCF should be stored into VariantDB. 



#### Set parental relations between samples.

```
perl scripts/Challenge_2.SetRelations.pl -u 'http://ec2-54-221-66-111.compute-1.amazonaws.com//variantdb' -a 5yeDJluF0kJOObbJZIKYWILhIZSaDYLJ -d 'files/Challenge_2'
```

##### Some  notes:
* Setting the correct relations allows application of a built-in 'de novo' filter for this challenge. 
* Alternatively, we could work with variant frequency in the project to get the correct result.

#### Launch the query

```
perl scripts/Challenge_2.Run.Query.pl -u 'http://ec2-54-221-66-111.compute-1.amazonaws.com//variantdb' -a 5yeDJluF0kJOObbJZIKYWILhIZSaDYLJ -d 'files/Challenge_2'
```

##### Some notes: 
* The needed filtersettings are saved in the provided image. They can be exported and imported (json) for use in other VariantDB instances.
* Results are returned as a json string holding with the VCF records of the matching variants included.
* The VCF is written to files/Challenge_2/Passing.Variants.vcf


#Result

```
No passing variants
```

##### Some notes:
* This is expected, as we are looking at a trio. So passing variants should be high quality de novo double hits.

