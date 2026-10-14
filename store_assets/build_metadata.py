"""Writes the store listing text files (App Store Connect + Google Play) and checks every limit.

    python store_assets/build_metadata.py

Edit the TEXT dict below, run it, and copy the files in metadata/<lang>/ into the store consoles.
Limits: App Store - name 30, subtitle 30, promo 170, description 4000, keywords 100 BYTES, what's new 4000.
        Google Play - title 30, short description 80, full description 4000.
"""
import os, sys

HERE = os.path.dirname(os.path.abspath(__file__))

TEXT = {
    "en": {
        "app_name": "Mostafa Solaiman",
        "subtitle": "Attendance & class updates",
        "promotional_text": "Your student ID and a live QR code, always on your phone - even offline. Check in over Bluetooth and get instant attendance confirmations.",
        "keywords": "attendance,student,math,qr code,bluetooth,class,teacher,school,egypt,notifications,tutor",
        "whats_new": "First release: sign in with email, Google or Apple, your student ID and live QR code, Bluetooth check-in, attendance history and notifications - in English and Arabic.",
        "play_short_description": "Your student ID, live QR code, attendance and class updates - works offline.",
        "description": """Mostafa Solaiman is the student app for Mr. Mostafa Solaiman's maths classes.

YOUR ID, ALWAYS WITH YOU
- Your student number and a QR code that renews itself every 30 seconds
- Both are saved on your phone, so they work even with no internet
- Show the code to your assistant when you arrive at the center

CHECK IN WITHOUT WAITING (BLUETOOTH)
- Open the app and tap Broadcast: your assistant's phone detects you from a short distance
- The moment you are counted you hear a chime and see "Assistant scanned you successfully" - also offline

KNOW YOUR ATTENDANCE
- Every class with its date, center and status (present or absent)
- Your attendance rate at a glance
- An instant notification when your attendance is recorded, plus messages from your teacher

SIGN IN YOUR WAY
- Email or phone number with your password, or continue with Google or Apple
- New student? Finish a short form and your account is ready

BUILT FOR YOU
- Full English and Arabic support (right-to-left)
- Fast and simple, and your information is kept private

GOOD TO KNOW
- You need an account on Mr. Mostafa Solaiman's platform (mostafa-solaiman.online); you can create one in the app or on the website
- Bluetooth check-in needs Bluetooth switched on and the "Nearby devices" permission, and works when your center has it enabled
- Signing in needs internet once; after that your ID and code work offline
""",
    },
    "ar": {
        "app_name": "مصطفى سليمان",
        "subtitle": "الحضور وتنبيهات الحصص",
        "promotional_text": "رقم الطالب وكود QR متجدد دائماً على هاتفك حتى بدون إنترنت. سجّل حضورك بالبلوتوث واستلم تأكيدات فورية.",
        "keywords": "حضور,طالب,رياضيات,كود,بلوتوث,حصة,مدرس,مدرسة,إشعارات",
        "whats_new": "الإصدار الأول: تسجيل الدخول بالبريد أو جوجل أو آبل، رقم الطالب وكود QR متجدد، تسجيل الحضور بالبلوتوث، سجل الحضور والإشعارات - بالعربية والإنجليزية.",
        "play_short_description": "رقم الطالب وكود QR والحضور وتنبيهات الحصص - يعمل بدون إنترنت.",
        "description": """مصطفى سليمان هو تطبيق الطالب لحصص الرياضيات مع مستر مصطفى سليمان.

رقمك وكودك معك دائماً
- رقم الطالب وكود QR يتجدد تلقائياً كل 30 ثانية
- كلاهما محفوظ على هاتفك فيعمل حتى بدون إنترنت
- اعرض الكود على المساعد عند وصولك إلى السنتر

سجّل حضورك بدون انتظار (بلوتوث)
- افتح التطبيق واضغط "ابدأ الإرسال" فيرصدك هاتف المساعد من مسافة قريبة
- لحظة احتسابك تسمع نغمة وترى "المساعد رصدك بنجاح" - حتى بدون إنترنت

تابع حضورك
- كل حصة بتاريخها والسنتر وحالتك (حاضر أو غائب)
- نسبة حضورك في لمحة
- إشعار فوري عند تسجيل حضورك، بالإضافة إلى رسائل المدرس

سجّل دخولك بالطريقة التي تناسبك
- البريد الإلكتروني أو رقم الهاتف مع كلمة المرور، أو تابع باستخدام جوجل أو آبل
- طالب جديد؟ أكمل نموذجاً قصيراً ويصبح حسابك جاهزاً

صُمم من أجلك
- دعم كامل للعربية (من اليمين لليسار) والإنجليزية
- سريع وبسيط، ومعلوماتك محفوظة بسرية

معلومات مهمة
- تحتاج إلى حساب على منصة مستر مصطفى سليمان (mostafa-solaiman.online) ويمكنك إنشاؤه من التطبيق أو من الموقع
- تسجيل الحضور بالبلوتوث يتطلب تشغيل البلوتوث وإذن "الأجهزة القريبة"، ويعمل عندما يفعّله السنتر الخاص بك
- تسجيل الدخول يحتاج إنترنت مرة واحدة؛ بعدها يعمل رقمك وكودك بدون إنترنت
""",
    },
}

# (key, file name, limit, unit)
LIMITS = [
    ("app_name", "app_store_name.txt", 30, "chars"),
    ("subtitle", "app_store_subtitle.txt", 30, "chars"),
    ("promotional_text", "app_store_promotional_text.txt", 170, "chars"),
    ("description", "description.txt", 4000, "chars"),
    ("keywords", "app_store_keywords.txt", 100, "bytes"),
    ("whats_new", "whats_new.txt", 4000, "chars"),
    ("play_short_description", "play_short_description.txt", 80, "chars"),
]

problems = 0
for lang, fields in TEXT.items():
    out = os.path.join(HERE, "metadata", lang)
    os.makedirs(out, exist_ok=True)
    print(f"[{lang}]")
    for key, fname, limit, unit in LIMITS:
        value = fields[key].strip()
        n = len(value.encode("utf-8")) if unit == "bytes" else len(value)
        flag = "ok " if n <= limit else "TOO LONG"
        if n > limit:
            problems += 1
        print(f"  {flag:8} {fname:34} {n:>5}/{limit} {unit}")
        open(os.path.join(out, fname), "w", encoding="utf-8", newline="\n").write(value + "\n")
    # Google Play title = the app name (30 chars)
    open(os.path.join(out, "play_title.txt"), "w", encoding="utf-8", newline="\n").write(fields["app_name"] + "\n")
    # keywords: Apple wants each keyword > 2 characters and no spaces after commas
    for kw in fields["keywords"].split(","):
        if len(kw.strip()) <= 2 or kw != kw.strip():
            print("  keyword problem:", repr(kw))
            problems += 1

print("\nALL LIMITS OK" if not problems else f"\n{problems} PROBLEM(S)")
sys.exit(1 if problems else 0)
