#Challenge #3. The cost projection problem.

### Current memory and storage usage.

* Memory : All queries can be performed using ~ 12Gb of memory.
* Storage : Used database : 44Gb

The question of 1 second response time is probably not feasible. VariantDB was designed to be flexible in storing, intersecting and retrieving variants in an interactive manner. It was not aimed specifically at realtime filtering (requiring instant results). We can however enhance querying time using:
* memcached (disabled by default). 
* more CPU's. Queries are split over CPUs both between filter settings (each rule is handled seperately) and within a single filtering rule (variants are sliced into multiple batches for parallel processing). 
* HPC : using VariantDB API, queries are launched in parallel if high peformance computing infrastructure is available. 

### Worst Case storage requirements for 100,000 genomes.

Currently, the variant table takes 25Mb for 330K unique variants. The worst case scenario of each sample having 100K new variants, leads to 10.10^9 variants, which is more than the size of the human genome. Therefore, I take 3.10^9.  This would result in a storage capacity of 225Gb.

Next, Variants_x_Samples relations currently take 35Gb for 137M rows. This is mainly due to extensive indexing on all default VCF fields. The total amount of rows here will be 3M * 100K == 3 * 10^11. This results in a storage requirement of ~76Tb. 

Finally, specified annotations take up 249Mb (ExAC.Info.AF) and 7Gb (SAVANT) for the benchmark dataset. Rescaled requirements would be:
* ExAC.Info.AF : 4.5.10^6 entries in 137M variant_x_sample combinations : ~ 1.10^10 entries in 100K samples. : ~ 500Gb
* Savant : 127.10^6 entries in 137M variant_x_sample combinations : ~ 2.8.10^11 entries in 100K samples. : ~ 15Tb

Total storage : ~92Tb.


### Worst Case memory requirements for 100,000 genomes.

Peak memory usage scales approximately linear with the number of unique variants in the querying results. 

Given current results:
* 330K variants requires ~ 10Gb of memory.

Rescaling this for monolithic processing result in ~90Tb of memory, which is not feasable. To overcome this, variants should be handled in batches of ~ 1M variants (~ 30Gb of memory) on HPC infrastructure, or sequentially on a single machine.



