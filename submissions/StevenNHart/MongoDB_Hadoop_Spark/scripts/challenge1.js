/*jslint node: true */
/*jshint -W069 */
'use strict';

//Find the samples to keep;
var getSample = function(doc) { return doc.samples };

var getEthnicity = function(line){
    var res1 = db.populations.findOne({SAMPLE: line.sampleID},{_id:0,Pop2:1})
    if( res1 === null){
        //Do nothing
    }else{
          finalResult[res1.Pop2]++
          //printjson(finalResult)
    }
};

var getSamplesThatMatchInfo = function(q){
  db.sampleFormat.find(q).forEach(
      function(line){
        //printjson(line)
        getEthnicity(line)
      }
    )
}


// Initalize variables
var POPS = db.populations.distinct("Pop2")
var finalResult = {}

for (var i=0;i<POPS.length;i++){
  finalResult[POPS[i]] = 0
}

var sampleEthnicGroups = db.populations.aggregate([
{
  $group:{
  _id:"$Pop2",
  "Samples": { "$addToSet": "$SAMPLE" }, 
  }
}
])

var excludeSamples = db.cryptic.aggregate([
    {   $match: {"Relationship": "Sibling","Population":"ASW"} },
  {
        "$group": {
      "_id": "$Population", 
      "Sample_1": { "$addToSet": "$Sample_1" }, 
      "Sample_2": { "$addToSet": "$Sample_2" }
    }
  },
  {
    "$project": {
      "samples": { "$setUnion": [ "$Sample_1", "$Sample_2" ] },
      "_id": 0
    }
   }
 ]).map(getSample)[0]


var infoCursor = db.info.find(
  {
    SAVANT_IMPACT : {$in: ["HIGH","MODERATE"]},
    $or: [ { "ExAC_Info_AF": { $lt: 0.1 } }, { "ExAC_Info_AF": null } ]
  }
);
var end = null
var q ={}
infoCursor.forEach(
    function(infoLine,len){
      q['chr']      = infoLine.chr;
      q['pos']      = Number(infoLine.pos);
      q['ref']      = infoLine.ref;
      q['alt']      = infoLine.alt;
      q['GT']       = {$in:['0/1','0|1']};
      q['AD_2']     = {$gt: 3};
      q['GQ']       = {$gt: 30};
      q['sampleID'] = {$nin:excludeSamples};
      var keep = infoCursor.hasNext()
      if(keep === true ){
        end = 0
      }else{
        end = 1
      }
      if(end === 0){
        getSamplesThatMatchInfo(q, end);
      }else{
        var res1 = db.populations.findOne({SAMPLE: q.sampleID},{_id:0,Pop2:1})
        if( res1 === null){
          //Do nothing
          printjson(finalResult)
        }else{
          finalResult[res1.Pop2]++
          printjson(finalResult)
        }
      }
    }
)




