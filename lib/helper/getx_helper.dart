import 'package:harismruti/helper/top_notification_helper.dart';

showTopNotification({required title, required message}) {
  TopNotification.show(title: title.toString(), message: message.toString());
}
