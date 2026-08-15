class FarmerRateRule {
 final double fatMin,fatMax,snfMin,snfMax,rate;
 FarmerRateRule(this.fatMin,this.fatMax,this.snfMin,this.snfMax,this.rate);
 factory FarmerRateRule.fromMap(Map<String,dynamic> m)=>FarmerRateRule((m['fat_min'] as num).toDouble(),(m['fat_max'] as num).toDouble(),(m['snf_min'] as num).toDouble(),(m['snf_max'] as num).toDouble(),(m['rate'] as num).toDouble());
}
class FarmerRateService {
 double calculate({required double fat,required double snf,required List<FarmerRateRule> rules,required double fallbackRate}) {
  for(final r in rules){if(fat>=r.fatMin&&fat<=r.fatMax&&snf>=r.snfMin&&snf<=r.snfMax)return r.rate;} return fallbackRate;
 }
}
