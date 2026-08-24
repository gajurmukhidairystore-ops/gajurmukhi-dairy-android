import 'package:flutter_contacts/flutter_contacts.dart';

class PickedPhoneContact {
  final String name;
  final String phone;

  const PickedPhoneContact({required this.name, required this.phone});
}

class ContactPickerService {
  Future<PickedPhoneContact?> pickPhone() async {
    final permission = await FlutterContacts.permissions.request(PermissionType.read);
    if (permission != PermissionStatus.granted) return null;

    final contact = await FlutterContacts.native.showPicker(
      properties: {ContactProperty.phone},
    );
    if (contact == null || contact.phones.isEmpty) return null;

    final phone = contact.phones.first.number.trim();
    if (phone.isEmpty) return null;
    return PickedPhoneContact(
      name: contact.displayName.trim(),
      phone: phone,
    );
  }
}
