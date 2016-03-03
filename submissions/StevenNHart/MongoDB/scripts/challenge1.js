//Find the samples to keep
var getSample = function(doc) { return doc.samples; }

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