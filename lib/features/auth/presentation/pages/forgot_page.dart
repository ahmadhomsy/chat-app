import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

// ** يجب استبدال هذا الجزء بالمسار الصحيح لملف الألوان الخاص بك **
// محاكاة لـ AppColors والألوان المستخدمة في التصميم الداكن
class AppColors {
  // لون الخلفية الداكنة (Dark background color)
  static const Color darkBackground = Color(0xFF1C212E);
  // لون النص الأساسي الفاتح
  static const Color lightText = Colors.white;
  // لون النص الثانوي الفاتح (مثل التلميحات)
  static const Color lightHintText = Colors.white70;
  // اللون الأساسي للأزرار والعناصر المميزة
  static const Color primaryBlue = Color(0xFF4A89F7);
  // لون خلفية حقل الإدخال الداكنة (شفافية بيضاء على الخلفية الداكنة)
  static const Color inputBgDark = Colors.white10;
}
// ------------------------------------------------------------------

class ForgotPasswordScreen extends StatelessWidget {
  const ForgotPasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // 1. زر العودة (Back Arrow)
              SizedBox(height: 12.h),
              const BackButton(color: AppColors.lightText),
              SizedBox(height: 24.h),

              // 2. قفل الصورة (Lock Image Placeholder)
              Center(child: _buildLockImagePlaceholder()),
              SizedBox(height: 32.h),

              // 3. العنوان الرئيسي
              Text(
                'Forgot Password?',
                style: TextStyle(
                  fontSize: 32.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.lightText,
                ),
              ),
              SizedBox(height: 8.h),

              // 4. النص الفرعي
              Text(
                "Don't worry! It happens. Please enter the email address associated with your account.",
                style: TextStyle(
                  fontSize: 16.sp,
                  color: AppColors.lightHintText,
                ),
              ),
              SizedBox(height: 40.h),

              // 5. حقل الإدخال (Email Address)
              _buildEmailInputField(),
              SizedBox(height: 40.h),

              // 6. زر Send Reset Link
              _buildSendResetLinkButton(),
              SizedBox(height: 40.h),

              // 7. رابط Login
              Center(child: _buildLoginLink(context)),
              SizedBox(height: 24.h),
            ],
          ),
        ),
      ),
    );
  }

  // ----------------------------------------------------
  // * المكونات المساعدة (Helper Widgets)
  // ----------------------------------------------------

  // بناء حاوية الصورة (يمكن استبدالها بصورة Asset حقيقية)
  Widget _buildLockImagePlaceholder() {
    // يمكن استبدال هذه الحاوية بمكون Image.asset أو Image.network
    // لعرض صورة القفل ثلاثية الأبعاد الموضحة في التصميم.
    return Container(
      width: 150.w,
      height: 150.w,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primaryBlue.withValues(
          alpha: 0.1,
        ), // لون خلفية دائري وهمي
        border: Border.all(
          color: Colors.teal.shade300,
          width: 2,
        ), // حدود وهمية لتمثيل الحلقة الخارجية
      ),
      child: Center(
        child: Icon(
          Icons.lock_outline, // أيقونة مؤقتة للقفل
          color: Colors.amber, // لون وهمي للقفل
          size: 70.sp,
        ),
      ),
    );
  }

  // بناء حقل إدخال البريد الإلكتروني (مصمم ليناسب الخلفية الداكنة)
  Widget _buildEmailInputField() {
    return Container(
      height: 56.h,
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      decoration: BoxDecoration(
        color: AppColors.inputBgDark, // خلفية شفافة داكنة
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Row(
        children: [
          const Icon(Icons.email_outlined, color: AppColors.lightHintText),
          SizedBox(width: 12.w),
          const Expanded(
            child: TextField(
              style: TextStyle(color: AppColors.lightText),
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                hintText: 'example@email.com',
                hintStyle: TextStyle(color: AppColors.lightHintText),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // بناء زر "Send Reset Link"
  Widget _buildSendResetLinkButton() {
    return SizedBox(
      width: double.infinity,
      height: 56.h,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryBlue,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.r),
          ),
          elevation: 0,
        ),
        onPressed: () {
          // منطق إرسال رابط إعادة التعيين
        },
        child: Text(
          'Send Reset Link',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.lightText,
          ),
        ),
      ),
    );
  }

  // بناء رابط "Login"
  Widget _buildLoginLink(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Remember your password? ',
          style: TextStyle(fontSize: 14.sp, color: AppColors.lightHintText),
        ),
        InkWell(
          onTap: () {
            // منطق الانتقال إلى صفحة تسجيل الدخول (Login)
            // Navigator.pop(context); // مثال للعودة للصفحة السابقة
          },
          child: Text(
            'Log In',
            style: TextStyle(
              fontSize: 14.sp,
              color: AppColors.primaryBlue,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
