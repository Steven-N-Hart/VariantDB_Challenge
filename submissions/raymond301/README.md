# Review Existing/Related Discussions

1. _Biostar: Do People Import Vcf Files Into Databases?_
  - [Question from 5 years ago](https://www.biostars.org/p/7372/), attempting to determine a database solution for storing variant data.
  - Claims SQL storage was still relevant, but adds unnecessary overhead.

2. _Biostar: Which Type Of Database Systems Are More Appropriate..._
  - [Update Question from #1](https://www.biostars.org/p/65920/) from 3 years ago.
  - Better discussion of various DBMS, but mostly discusses how there is no universally acceptable option.
  - Argument against any database: requires dependencies and specialized environments.
  - Suggested SQLite (backend for portability and flexibility) + App [Gemini](https://github.com/arq5x/gemini) OR [VariationToolKit](https://github.com/lindenb/variationtoolkit) and additional [Blog](http://plindenbaum.blogspot.com/2012_01_01_archive.html), [Update](https://github.com/lindenb/jvarkit/wiki/VCF2SQL)
  - Suggestion for MongoDB + SQL hyrid system...argued against due to complexity and reduced flexibility.
  - Open ended suggestion for [SciDB](http://forum.paradigm4.com/c/general) by [Amos](https://github.com/slottad/scidb-genotypes).
  
3. _Ensembl MySQL database from a VCF_
  - [Script Usage](http://useast.ensembl.org/info/genome/variation/import_vcf.html?redirect=no) Page
  - Already designed to read 1000 Genomes vcf and meta data.
  - Claim: The speed of import can be vastly increased by running simultaneous CPU processes.
  
4. _Magnolia: Microarray Data Management Tool_
  - Microarray, although not VCF variants, [database made with H2 mem](http://sourceforge.net/p/magnoliamdmt/code/HEAD/tree/trunk/doc/)
  - Appears to be good for Meta data, but lacks examples. [Java from Craig Venter Inst.](http://www.mybiosoftware.com/magnolia-1-2-microarray-data-management-export-system-pfgrc-microarrays.html)
  - [H2 documentation](http://www.h2database.com/html/mvstore.html), for performance in mem.
  
5. _GeneTrack: analysis system designed to store genome wide information_
  - Built in [HDF](https://www.hdfgroup.org/HDF5/) (hierarchical data format).
  - [App written in python](http://atlas.bx.psu.edu/genetrack/docs/genetrack.html), designed with simplicity, accessibility and performance in mind.
  
6. _CanvasDB: Uppsala Solution_
  - [Purpose for genetic variants](http://www.ncbi.nlm.nih.gov/pmc/articles/PMC4184106/) from massively parallel sequencing.
  - [Code examples](https://github.com/UppsalaGenomeCenter/CanvasDB) in R
  
7. _PlinkSeq: SEQDB for VCFs_
  - [load-vcf command](http://atgu.mgh.harvard.edu/plinkseq/input.shtml#vcf), has basic data retrieval capabilities.
  
8. _Genetalk: A Platform To Analyse Your Genetic Variant Data And Talk_
  - web-based platform, tool, and database, for filtering, reduction and prioritization of human sequence variants from next-generation sequencing (NGS) data.
  - [Biostar Question](https://www.biostars.org/p/80078/)
  
9. _MyNCList: Rapid storage and retrieval of genomic intervals from a relational database..._
  - An [implementation within MySQL](http://www.ncbi.nlm.nih.gov/pmc/articles/PMC3724366/), achieves better query performance by hierarchically organizing all nested intervals.