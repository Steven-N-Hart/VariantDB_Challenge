# Review Existing Discussions

1. _Biostar: Do People Import Vcf Files Into Databases?_
  - [Question from 5 years ago](https://www.biostars.org/p/7372/), attempting to determine a database solution for storing variant data.
  - Claims SQL storage was still relevant, but adds unnecessary overhead.

2. _Biostar: Which Type Of Database Systems Are More Appropriate..._
  - [Update Question from #1](https://www.biostars.org/p/65920/) from 3 years ago.
  - Better discussion of various DBMS, but mostly discusses how there is no universally acceptable option.
  - Argument against any database: requires dependencies and specialized environments.
  - Suggested SQLite (backend for portability and flexibility) + App [Gemini](https://github.com/arq5x/gemini) OR [VariationToolKit](https://github.com/lindenb/variationtoolkit) and additional [Blog](http://plindenbaum.blogspot.com/2012_01_01_archive.html)
  - Suggestion for MongoDB + SQL hyrid system...argued against due to complexity and reduced flexibility.
  - Open ended suggestion for SciDB.
  
3. _Ensembl mySQL database from a VCF_
  - [Script Usage](http://useast.ensembl.org/info/genome/variation/import_vcf.html?redirect=no) Page
  - Already designed to read 1000 Genomes vcf and meta data.
  - Claim: The speed of import can be vastly increased by running simultaneous CPU processes.