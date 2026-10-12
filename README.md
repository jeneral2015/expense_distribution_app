# برنامج توزيع المصاريف

تطبيق Flutter لإدارة المشتريات والاشتراكات، توزيع الوجبات والمشروبات، توزيع النثريات، وتقفيل الشهر — مع قاعدة بيانات محلية (SQLite) ومزامنة اختيارية لكل مستخدم عبر Firebase.

## الميزات الجديدة

- تسجيل الدخول وإنشاء حساب (Firebase Authentication)
- قاعدة محلية لكل مستخدم + نسخة على Cloud Firestore
- مزامنة: ذكية / رفع / تنزيل من صفحة **قاعدة البيانات**
- واجهة Material 3 متجاوبة (موبايل، تابلت، لاب توب)
- نشر كتطبيق ويب على Firebase Hosting

> منطق توزيع المصروفات، تقفيل الشهر، والنثريات **لم يُغيَّر** — التعديلات في المصادقة، المزامنة، والواجهة فقط.

## إعداد Firebase

1. أنشئ مشروعاً في [Firebase Console](https://console.firebase.google.com/)
2. فعّل **Authentication** → Email/Password
3. أنشئ **Cloud Firestore**
4. انسخ `firestore.rules.example` إلى `firestore.rules` وانشر القواعد
5. ثبّت FlutterFire CLI ثم من جذر المشروع:

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

6. انسخ `.firebaserc.example` إلى `.firebaserc` وضع `projectId` الصحيح

## تشغيل محلياً (ويب)

```bash
flutter pub get
flutter run -d chrome
```

## بناء ونشر الويب على Firebase Hosting

```bash
flutter build web --release
firebase login
firebase deploy --only hosting
```

## بدون Firebase (تطوير)

طالما `lib/firebase_options.dart` يحتوي على قيم `YOUR_*`، يعمل التطبيق **بدون** إجبار تسجيل الدخول (كما في الإصدارات السابقة)، مع SQLite محلي فقط.
