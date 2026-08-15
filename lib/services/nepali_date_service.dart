import 'package:bikram_sambat/bikram_sambat.dart';
class NepaliDateService {
 static String today()=>BikramSambat.now().format(BSDateFormat.yMMMMd(BSLanguage.nepali));
 static String fromAd(DateTime d)=>d.toBikramSambat().format(BSDateFormat.yMd());
}
