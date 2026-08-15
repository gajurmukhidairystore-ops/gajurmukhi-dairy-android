import 'package:qr_flutter/qr_flutter.dart';
class QrPaymentService {
 String payload({required String merchantId,required String invoiceNo,required double amount})=>'merchant=$merchantId&invoice=$invoiceNo&amount=${amount.toStringAsFixed(2)}';
 QrImageView widget({required String merchantId,required String invoiceNo,required double amount})=>QrImageView(data:payload(merchantId:merchantId,invoiceNo:invoiceNo,amount:amount),size:220);
}
