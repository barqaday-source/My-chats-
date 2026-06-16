# C Chat - سي شات 💬

تطبيق دردشة اجتماعي متكامل مبني بـ Flutter + Supabase

## الميزات

- 🔐 تسجيل دخول بالإيميل وجوجل
- 💬 دردشة خاصة مشفرة بين طرفين  
- 🏠 غرف دردشة جماعية مع صور خلفية
- 🎤 تسجيل رسائل صوتية
- 📷 رفع صور في المحادثات والملف الشخصي
- 🟢 حالة النشاط الحقيقية
- 🔔 إشعارات فورية مع صوت
- 👑 لوحة إدارة للمشرفين والمديرين
- 🚫 حظر مستخدمين نهائياً
- 📊 نظام بلاغات مع ردود على الإشعارات
- 🌙 تصميم داكن زجاجي موحد
- 🇸🇦 واجهة عربية كاملة بخط تاجوال

## إعداد المشروع

### 1. متطلبات النظام
- Flutter SDK 3.0+
- Dart 3.0+
- Android Studio / VS Code

### 2. إعداد Supabase
1. افتح [Supabase Dashboard](https://supabase.com/dashboard)
2. اذهب إلى SQL Editor
3. شغّل ملف `SUPABASE_SETUP.sql` بالكامل
4. اذهب إلى Storage وأنشئ 4 buckets:
   - `avatars` (public)
   - `room-images` (public)  
   - `chat-media` (public)
   - `audio-messages` (public)

### 3. تشغيل التطبيق
```bash
flutter pub get
flutter run
```

### 4. بيانات Supabase (موجودة مسبقاً)
```
URL: https://jmsmrojtlstppnpwmkkk.supabase.co
Anon Key: موجود في lib/core/constants/supabase_config.dart
```

### 5. ربط جوجل (اختياري)
- أضف `google-services.json` لأندرويد
- أضف `GoogleService-Info.plist` لـ iOS
- فعّل Google Auth في Supabase Dashboard

## هيكل المشروع
```
lib/
├── core/           # الألوان، الثيم، الثوابت
├── models/         # نماذج البيانات
├── services/       # خدمات Supabase
├── providers/      # إدارة الحالة
├── screens/        # الشاشات
│   ├── splash/     # شاشة التحميل
│   ├── auth/       # تسجيل الدخول
│   ├── home/       # الشاشة الرئيسية
│   ├── rooms/      # الغرف
│   ├── chat/       # الدردشات
│   ├── profile/    # الملف الشخصي
│   ├── notifications/ # الإشعارات
│   ├── admin/      # لوحة الإدارة
│   └── pages/      # صفحات إضافية
└── widgets/        # المكونات المشتركة
```

## الخطوط
ضع ملفات خط Tajawal في `assets/fonts/`:
- `Tajawal-Regular.ttf`
- `Tajawal-Medium.ttf`
- `Tajawal-Bold.ttf`
- `Tajawal-ExtraBold.ttf`

حمّل الخط من: https://fonts.google.com/specimen/Tajawal

## ملاحظات
- التطبيق يعمل على Android و iOS
- مدمج مع Supabase Realtime للرسائل الفورية
- المحادثات المشفرة تدعم XOR + مكتبة encrypt
