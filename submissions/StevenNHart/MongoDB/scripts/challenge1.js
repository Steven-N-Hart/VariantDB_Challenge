
var SAMPLES = []
db.cryptic.find({Population: {$not :/"ASW"/}, Relationship: {$not: /"Sibling"/}},{"Sample_1":1, "Sample_2":1, _id:0}).forEach(function(doc){SAMPLES.push(doc.Sample_1);SAMPLES.push(doc.Sample_2)})

var getSample = function(doc) { return doc.samples; }

var getEthnicity = function(line){
    var res1 = db.populations.findOne({SAMPLE: line.sampleID},{_id:0,Pop2:1})
    if( res1 === null){
        //Do nothing
    }else{
          finalResult[res1.Pop2]++
          //printjson(finalResult)
    }
}

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

for (i=0;i<POPS.length;i++){
  finalResult[POPS[i]] = 0
}

// Create a key for each population and add an array f samples in that population
var sampleEthnicGroups = db.populations.aggregate([
{
  $group:{
  _id:"$Pop2",
  "Samples": { "$addToSet": "$SAMPLE" }, 
  }
}
])


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
      q['AD_2']     = {$gt: 10};
      q['GQ']       = {$gt: 30};
      q['sampleID'] = {$in:SAMPLES};
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

