var hets = db.sampleFormat.find(
    {$and : [
     { "GT": 
      { $in: ["0/1", "0|1"] } 
     },
     {"sample" : "NA12878i"}]
    }
)
print('#CHROM','POS','ID','REF','ALT','QUAL','FILTER','INFO','FORMAT','NA12878i','NA12891','NA12892')

//Cross reference the blocks to get the corresponding band data
hets.forEach( function (het){
  var chr = het.chr
  var ref = het.ref
  var alt = het.alt
  var pos = Number(het.pos)
  var gt = het.GT+':'+het.GQ+':'+het.DP+':'+het.PL.join()
  var res = db.block.aggregate(
    [
      // Stage 1
      {
        $match: { 
          $and: [ 
            { "chr": chr }, 
            { "start": 
              { $lte: Number(pos) } 
            }, 
            { "end": 
              { $gte: Number(pos)} 
              } 
          ]
         }
      },
      // Stage 2
      {
        $group: {
          _id : "$chr",
          samples: { $push : "$sample"},
          format: {$first: "$format"},
          sampleFormat:{$push : "$sampleFormat"},
          chr : {$first : chr},
          pos : {$first :pos},
          ref : {$first :ref},
          alt : {$first :alt},
          gt: {$first: gt}
        }
      }
    ]
  )
  .toArray()
  .forEach( function (res){
      if(res.samples.length>1){
        var s = res.sampleFormat.join('\t') 
        print(res.chr,res.pos,'.',res.ref,res.alt,'.','.','.',res.format,gt,s)
      }
  })
});
