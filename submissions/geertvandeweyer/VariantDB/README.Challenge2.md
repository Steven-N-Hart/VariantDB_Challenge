Challenge #2. The continuous integration problem.

VariantDB is a mysql-based web & api based querying tool.  

## Installation 

cfr README.Challenge1.md. The same instance should be used.




#### Load data.

Samples are loaded remotely into VariantDB. No need to download & parse locally.

```
perl scripts/Import.Data.pl -s files/Challenge_2/SampleSheet.txt -u 'http://127.0.0.1/variantdb' -p Challenge_2 -a YOUR_API_KEY
```

##### Some  notes:
* -a : api key for variantdb. you can  find this using the web-interface by clicking on your username, my details.
* In the samplesheet, the second to last column specifies whether or not the VCF should be stored into VariantDB. 



#### Set parental relations between samples.

```
perl scripts/Challenge_2.SetRelations.pl -u 'http://127.0.0.1/variantdb' -a YOUR_API_KEY -d 'files/Challenge_2'
```

##### Some  notes:
* Setting the correct relations allows application of a built-in 'de novo' filter for this challenge. 
* Alternatively, we could work with variant frequency in the project to get the correct result.

#### Load The Filters for Challenge_1
Filter settings are available in json format and will be imported into your VariantDB installation.

```
python scripts/Import.Settings.py -u 'http://127.0.0.1/variantdb/api/' -k YOUR_API_KEY -I files/Challenge_1/Filter.Challenge_2.json -t f
```




#### Launch the query

```
perl scripts/Challenge_2.Run.Query.pl -u 'http://127.0.0.1/variantdb' -a YOUR_API_KEY -d 'files/Challenge_2'
```

##### Some notes: 
* Results are returned as a json string holding with the VCF records of the matching variants included.
* The VCF is written to files/Challenge_2/Passing.Variants.vcf


#Result

```
No passing variants
```

##### Some notes:
* This is expected, as we are looking at a trio. So passing variants should be high quality de novo double hits.

